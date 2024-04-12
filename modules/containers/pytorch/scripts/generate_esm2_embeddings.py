from transformers import AutoTokenizer, AutoModel, BitsAndBytesConfig
import torch
import numpy as np
import argparse
import csv


def generate_embeddings(
    text: list,
    model_name: str = "facebook/esm2_t36_3B_UR50D",
    batch_size: int = 24,
    quant: bool = False,
    output_file: str = "embeddings.npy",
):

    if quant:
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
        )
    else:
        bnb_config = None

    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModel.from_pretrained(
        model_name, device_map="auto", quantization_config=bnb_config
    )

    tmp = []
    total_batches = len(text) // batch_size
    for n, batch in enumerate(
        [text[i : i + batch_size] for i in range(0, len(text), batch_size)]
    ):
        print(f"Batch {n+1} of {total_batches}")
        inputs = tokenizer(
            batch, return_tensors="pt", truncation=True, padding=True, max_length=1024
        )
        with torch.no_grad():
            predictions = model(**inputs)
        # Return mean embeddings after removing <cls> and <eos> tokens and converting to numpy.
        tmp.append(predictions.last_hidden_state[:, 1:-1, :].numpy().mean(axis=1))
    output = np.vstack(tmp)
    print(f"Output shape: {output.shape}")
    print(f"Saving embeddings to {output_file}")
    output.save
    return output_file


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file", help="Path to input CSV file with sequences to process", type=str
    )
    parser.add_argument(
        "--model_name",
        help="ESM model to use",
        default="facebook/esm2_t36_3B_UR50D",
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
        help="Whether to use 4bit quant for model inference",
        default=False,
        type=bool,
    )
    parser.add_argument(
        "--output_file",
        help="(Optional) file name of an output file for the filtered fasta",
        default="embeddings.npy",
        type=str,
    )

if __name__ == "__main__":

    args = parser.parse_args()
    with open(args.input_file, newline="") as csvfile:
        reader = csv.reader(csvfile)
        seqs = [row[1] for row in reader]
    output = generate_embeddings(
        seqs, args.model_name, args.batch_size, args.quant, args.output_file
    )
    print(output)
