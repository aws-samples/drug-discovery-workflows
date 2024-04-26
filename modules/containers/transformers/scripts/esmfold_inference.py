# Original Copyright 2022 Facebook, Inc. and its affiliates.
# Modifications Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import argparse
import json

# import esm
import logging
from matplotlib.colors import LinearSegmentedColormap
import matplotlib.pyplot as plt
from pathlib import Path
import re
from resource import getrusage, RUSAGE_SELF
import sys
from time import gmtime, strftime
from timeit import default_timer as timer
import torch
import typing as T
import uuid
import csv
from transformers import AutoTokenizer, EsmForProteinFolding
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)
formatter = logging.Formatter(
    "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%y/%m/%d %H:%M:%S",
)
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
PathLike = T.Union[str, Path]


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
    return None


if __name__ == "__main__":
    start_time = timer()
    metrics = {
        "model_name": "ESMFold",
        "start_time": strftime("%d %b %Y %H:%M:%S +0000", gmtime()),
    }
    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--input_file",
        help="Path to input file",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "-o", "--pdb", help="Path to output PDB directory", type=Path, required=True
    )
    parser.add_argument(
        "-m",
        "--model-dir",
        help="Parent path to Pretrained ESM data directory. ",
        type=Path,
        default="data/weights",
    )

    args = parser.parse_args()
    if not args.input_file.exists():
        raise FileNotFoundError(args.input_file)
    args.pdb.mkdir(exist_ok=True)

    # Read input_file and sort sequences by length
    logger.info(f"Reading sequences from {args.input_file}")
    start_sequence_load_time = timer()
    with open(args.input_file, newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        all_sequences = [row["text"] for row in reader]

    # if len(all_sequences) > 1:
    # seq = all_sequences[0]

    seq_count = len(all_sequences)

    logger.info(f"Loaded {seq_count} sequences from {args.input_file}")
    metrics.update(
        {"timings": {"sequence_load": round(timer() - start_sequence_load_time, 3)}}
    )

    # Load models
    logger.info("Loading model")
    start_model_load_time = timer()

    model = EsmForProteinFolding.from_pretrained(args.model_dir)
    tokenizer = AutoTokenizer.from_pretrained(args.model_dir)
    metrics["timings"].update({"model_load": round(timer() - start_model_load_time, 3)})

    # Predict structure
    logger.info("Starting Predictions")
    metrics["predictions"] = []
    start_prediction_time = timer()
    for i, seq in enumerate(all_sequences):
        logger.info(f"Predicting sequence {i}")
        logger.info(f"Raw input is {seq}")
        metrics["predictions"].append({"sequence": seq, "length": len(seq)})
        inputs = tokenizer(seq, return_tensors="pt", add_special_tokens=False)

        try:
            output = model(**inputs)
        except RuntimeError as err:
            metrics.update({"error": err.args[0]})
            metrics.update({"end_time": strftime("%d %b %Y %H:%M:%S +0000", gmtime())})
            with open(os.path.join(args.pdb, i, "metrics.json", "w")) as f:
                json.dump(metrics, f)
            raise
        except Exception as err:
            metrics.update({"error": err})
            metrics.update({"end_time": strftime("%d %b %Y %H:%M:%S +0000", gmtime())})
            with open(os.path.join(args.pdb, i, "metrics.json", "w")) as f:
                json.dump(metrics, f)
            raise
        metrics["predictions"][i].update(
            {"prediction_time": round(timer() - start_prediction_time, 3)}
        )

        # Parse outputs
        start_output_time = timer()
        output = {key: value.cpu() for key, value in output.items()}
        pdb_string = model.output_to_pdb(output)[0]
        output_file = os.path.join(args.pdb, i, "prediction.pdb")
        output_file.write_text(pdb_string)
        mean_plddt = round(output["mean_plddt"].item(), 3)
        ptm = round(output["ptm"].item(), 3)
        max_predicted_aligned_error = round(
            output["max_predicted_aligned_error"].item(), 3
        )
        peak_mem = getrusage(RUSAGE_SELF).ru_maxrss / 1000000
        peak_gpu_mem = torch.cuda.max_memory_allocated() / 1000000000

        torch.save(output, os.path.join(args.pdb, i, "outputs.pt"))

        pae = output["predicted_aligned_error"]
        plot_pae(pae[0], os.path.join(args.pdb, i, "pae.png"))

        metrics["predictions"][i].update(
            {
                "pLDDT": mean_plddt,
                "pTM": ptm,
                "max_predicted_aligned_error": max_predicted_aligned_error,
                "peak_memory_gb": peak_mem,
                "peak_gpu_memory_gb": peak_gpu_mem,
            }
        )

        metrics["predictions"][i].update({"output_time": round(timer() - start_output_time, 3)})
        seq_end_time = timer()
        seq_total_time = round(seq_end_time - start_time, 3)
        logger.info(
            f"Predicted structure length {len(seq)}, pLDDT {mean_plddt}, "
            f"pTM {ptm} in {seq_total_time}s. "
            f"Peak memory usage (GB) {peak_mem}. "
            f"Peak GPU memory usage (GB) {peak_gpu_mem}."
        )
    end_time = timer()
    total_time = round(end_time - start_time, 3)
    metrics["timings"].update({"total": total_time})
    metrics.update({"end_time": strftime("%d %b %Y %H:%M:%S +0000", gmtime())})        
    with open(os.path.join(args.pdb, "metrics.json", "w")) as f:
        json.dump(metrics, f)
