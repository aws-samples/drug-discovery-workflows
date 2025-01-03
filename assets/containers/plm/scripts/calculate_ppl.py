# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
import jsonlines
import logging
import math
import numpy as np
import pyfastx
from transformers import AutoModel, AutoTokenizer
import torch
from tqdm import tqdm
import os

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)

def batch_tokenize_mask(dataset, tokenizer, batch_size):
    for i, protein in enumerate(dataset):
        label = str(i)
        x = torch.as_tensor(tokenizer.encode(protein, max_length=512, truncation=True))
        x = x.repeat(x.size(0), 1)
        y = torch.where(torch.eye(x.size(0), dtype=torch.bool), x, -100)
        x = torch.where(
            torch.eye(x.size(0), dtype=torch.bool), tokenizer.mask_token_id, x
        )
        for _x, _y in zip(torch.split(x, batch_size, 0), torch.split(y, batch_size, 0)):
            yield (label, _x, _y)


def compute_pseudo_perplexity(
    seqs: list,
    pretrained_model_name_or_path: str = "chandar-lab/AMPLIFY_120M_base",
    batch_size: int = 8,
    output_dir: str = "output",
    fp16: bool = True,
):

    device = "cuda:0" if torch.cuda.is_available() else "cpu"

    model = AutoModel.from_pretrained(
        pretrained_model_name_or_path, trust_remote_code=True
    )
    tokenizer = AutoTokenizer.from_pretrained(
        pretrained_model_name_or_path, trust_remote_code=True
    )
    model = model.to(device)

    logging.info(f"Generating embeddings for {len(seqs)} sequences")
    seq_text = [seq[1] for seq in seqs]
    dataloader = batch_tokenize_mask(seq_text, tokenizer, batch_size)
    n_iterations = math.ceil((len("".join(seq_text)) + len(seq_text) * 2) / batch_size)

    with torch.inference_mode(), torch.autocast(
        device_type=device, dtype=torch.float16, enabled=fp16
    ):
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
        losses = dict()
        loss_fn = torch.nn.CrossEntropyLoss(ignore_index=-100, reduction="none")
        for label, x, y in tqdm(dataloader, total=n_iterations):
            x = x.to(device)
            y = y.to(device)
            logits = model(x).logits
            loss = loss_fn(logits.transpose(1, 2), y).sum(-1).tolist()
            losses[label] = losses[label] + loss if label in losses else loss

    ppl_values = [float(np.exp(np.mean(v))) for v in losses.values()]

    output_file = os.path.join(output_dir, "ppl.jsonl")
    print(f"Saving perplexity values to {output_file}")

    results = []

    for name, ppl in zip([seq[0] for seq in seqs], ppl_values):
        results.append({"name": name, "pseudo_perplexity": ppl})

    with jsonlines.open(output_file, mode="w") as writer:
        writer.write_all(results)

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
        default="chandar-lab/AMPLIFY_120M_base",
        type=str,
    )
    parser.add_argument(
        "--batch_size",
        help="Number of sequences per batch",
        default=8,
        type=int,
    )
    parser.add_argument(
        "--output_dir",
        help="(Optional) Path to output dir",
        default="output",
        type=str,
    )

    args = parser.parse_args()
    seqs = [seq for seq in pyfastx.Fasta(args.input_file, build_index=False)]

    logging.info(f"Calculating pseudo-perplexity values for {args.input_file}")

    compute_pseudo_perplexity(
        seqs,
        args.pretrained_model_name_or_path,
        args.batch_size,
        args.output_dir,
    )
