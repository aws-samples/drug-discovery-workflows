# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
import logging
import numpy as np
import pyfastx
import torch
from tqdm import tqdm
from transformers import AutoTokenizer, AutoModel, BitsAndBytesConfig

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def generate_embeddings(
    text: list,
    pretrained_model_name_or_path: str = "facebook/esm2_t33_650M_UR50D",
    batch_size: int = 24,
    quant: bool = False,
    output_file: str = "embeddings.npy",
):
    device = "cuda:0" if torch.cuda.is_available() else "cpu"

    if quant and device != "cpu":
        logging.info("Quantizing model")
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
        )
    else:
        bnb_config = None

    tokenizer = AutoTokenizer.from_pretrained(
        pretrained_model_name_or_path, trust_remote_code=True
    )
    model = AutoModel.from_pretrained(
        pretrained_model_name_or_path,
        quantization_config=bnb_config,
        trust_remote_code=True,
    ).to(device)

    tmp = []
    logging.info(f"Generating embeddings for {len(text)} sequences")
    total_batches = (len(text) // batch_size) + 1
    for n, batch in tqdm(
        enumerate([text[i : i + batch_size] for i in range(0, len(text), batch_size)]),
        desc="Generating embeddings",
    ):
        print(f"Batch {n+1} of {total_batches}")
        inputs = tokenizer(
            batch,
            return_tensors="pt",
            return_attention_mask=False,  # avoid dtype error on attention_mask for AMPLIFY
            truncation=True,
            padding=True,
            max_length=1024,
        ).to(device)
        with torch.inference_mode():
            predictions = model(**inputs, output_hidden_states=True)
        # take last hidden state as embedding
        per_token_emb = predictions["hidden_states"][-1]
        # Return mean embeddings after removing <cls> and <eos> tokens and converting to numpy.
        tmp.append(per_token_emb[:, 1:-1, :].cpu().numpy().mean(axis=1))
    output = np.vstack(tmp)
    print(f"Output shape: {output.shape}")
    print(f"Saving embeddings to {output_file}")
    np.save(output_file, output)
    return output_file


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file",
        help="Path to input fasta file with sequences to process",
        type=str,
    )
    parser.add_argument(
        "--pretrained_model_name_or_path",
        help="pLM model to use",
        default="facebook/esm2_t33_650M_UR50D",
        type=str,
    )
    parser.add_argument(
        "--batch_size",
        help="Number of sequences per batch",
        default=24,
        type=int,
    )
    parser.add_argument(
        "--quant",
        action="store_true",
        help="Whether to use 4bit quant for model inference",
        default=False,
    )
    parser.add_argument(
        "--output_file",
        help="(Optional) file name of an output file for the filtered fasta",
        default="embeddings.npy",
        type=str,
    )

    args = parser.parse_args()
    seqs = [i.seq for i in pyfastx.Fasta(args.input_file)]

    generate_embeddings(
        seqs,
        args.pretrained_model_name_or_path,
        args.batch_size,
        args.quant,
        args.output_file,
    )
