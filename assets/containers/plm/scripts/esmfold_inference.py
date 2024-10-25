# Original Copyright 2022 Facebook, Inc. and its affiliates.
# Modifications Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
import json
import logging
from matplotlib.colors import LinearSegmentedColormap
import matplotlib.pyplot as plt
import os
import pyfastx
import torch
from transformers import AutoTokenizer, EsmForProteinFolding
from tqdm import tqdm

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def plot_pae(pae, output) -> None:
    fig = plt.figure()
    ax = fig.add_subplot()
    hcls_cmap = LinearSegmentedColormap.from_list(
        "hclscmap", ["#FFFFFF", "#007FAA", "#005276"]
    )
    _ = plt.imshow(pae, vmin=0.0, vmax=pae.max(), cmap=hcls_cmap)
    ax.set_title("Predicted Aligned Error")
    ax.set_xlabel("Scored residue")
    ax.set_ylabel("Aligned residue")
    fig.savefig(output)
    plt.close(fig)
    return None


def predict_structures(
    seqs: list,
    pretrained_model_name_or_path: str = "facebook/esmfold_v1",
    output_dir: str = "output",
):

    device = "cuda:0" if torch.cuda.is_available() else "cpu"

    tokenizer = AutoTokenizer.from_pretrained(pretrained_model_name_or_path)
    model = EsmForProteinFolding.from_pretrained(pretrained_model_name_or_path).to(
        device
    )

    logging.info(f"Predicting structures for {len(seqs)} sequences")
    for n, seq in tqdm(
        enumerate(seqs),
        desc=f"Generating structures",
    ):
        logging.info(f"Sequence {n+1} of {len(seqs)}")
        metrics = {"sequence": seq, "sequence_length": len(seq)}
        inputs = tokenizer(seq, return_tensors="pt", add_special_tokens=False).to(
            device
        )
        with torch.inference_mode():
            outputs = model(**inputs)

        output = {key: value.cpu() for key, value in outputs.items()}
        pdb_string = model.output_to_pdb(output)[0]
        output_dir = os.path.join(args.output_dir, str(n))
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

        output_file = os.path.join(output_dir, "prediction.pdb")

        with open(output_file, "w") as f:
            f.write(pdb_string)
        metrics.update(
            {
                "mean_plddt": round(torch.mean(output["plddt"]).item(), 3),
                "ptm": round(output["ptm"].item(), 3),
                "max_predicted_aligned_error": round(
                    output["max_predicted_aligned_error"].item(), 3
                ),
            }
        )
        torch.save(output, os.path.join(output_dir, "outputs.pt"))
        pae = output["predicted_aligned_error"]
        plot_pae(pae[0], os.path.join(output_dir, "pae.png"))
        with open(os.path.join(output_dir, "metrics.json"), "w") as f:
            json.dump(metrics, f)


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file",
        help="Path to input fasta file with sequences to process",
        type=str,
    )
    parser.add_argument(
        "--pretrained_model_name_or_path",
        help="ESMFold model to use",
        default="facebook/esmfold_v1",
        type=str,
    )
    parser.add_argument(
        "--output_dir",
        help="(Optional) Path to output dir",
        default="output",
        type=str,
    )

    args = parser.parse_args()
    seqs = [i.seq for i in pyfastx.Fasta(args.input_file)]

    predict_structures(
        seqs,
        args.pretrained_model_name_or_path,
        args.output_dir,
    )
