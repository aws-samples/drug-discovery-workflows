# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
import json
import logging
import os
from pathlib import Path
import pyfastx
import re
import torch

import shutil
from chai_lab.chai1 import run_inference

# We use fasta-like format for inputs.
# - each entity encodes protein, ligand, RNA or DNA
# - each entity is labeled with unique name;
# - ligands are encoded with SMILES; modified residues encoded like AAA(SEP)AAA

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def main(
    fasta_path,
    device="cuda:0" if torch.cuda.is_available() else "cpu",
    num_diffn_timesteps=200,
    num_trunk_recycles=3,
    output_dir="output",
    seed=None,
    use_esm_embeddings=True,
):

    input_records = pyfastx.Fasta(fasta_path, build_index=False)
    sequence_name = None

    with open("input.fasta", "w") as f:
        for record in input_records:
            # Use the first sequence in the input fasta for output naming
            sequence_name = sequence_name or record[0]
            if not re.match("(protein|ligand|rna|dna|glycan)", record[0]):
                name = "protein|" + record[0]
            else:
                name = record[0]
            f.write(f">{name}\n{record[1]}\n")

    fasta_path = Path("input.fasta")

    # Inference expects an empty directory; enforce this
    output_dir = Path(output_dir)
    if output_dir.exists():
        logging.warning(f"Removing old output directory: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(exist_ok=True)

    candidates = run_inference(
        fasta_file=fasta_path,
        output_dir=output_dir,
        num_trunk_recycles=num_trunk_recycles,
        num_diffn_timesteps=num_diffn_timesteps,
        seed=seed,
        device=device,
        use_esm_embeddings=use_esm_embeddings,
    )

    best_structure = candidates.sorted().cif_paths[0]
    best_metrics = candidates.sorted().ranking_data[0]

    metrics = {
        "name": sequence_name,
        "best_structure_path": str(best_structure),
        "best_structure_aggregate_score": best_metrics.aggregate_score.item(),
        "best_structure_complex_ptm": best_metrics.ptm_scores.complex_ptm.item(),
        "best_structure_interface_ptm": best_metrics.ptm_scores.interface_ptm.item(),
        "best_structure_complex_plddt": best_metrics.plddt_scores.complex_plddt.item(),
        "best_structure_total_clashes": best_metrics.clash_scores.total_clashes.item(),
        "best_structure_total_inter_chain_clashes": best_metrics.clash_scores.total_inter_chain_clashes.item(),
        "best_structure_has_inter_chain_clashes": best_metrics.clash_scores.has_inter_chain_clashes.item(),
    }

    logging.info(metrics)
    with open(os.path.join(output_dir, sequence_name + ".json"), "w") as f:
        json.dump(metrics, f)
        f.write("\n")

    return metrics


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("fasta_path", type=str)
    parser.add_argument("--device", type=str, default="cuda:0")
    parser.add_argument("--num_diffn_timesteps", type=int, default=200)
    parser.add_argument("--num_trunk_recycles", type=int, default=3)
    parser.add_argument("--output_dir", type=str, default="output")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--use_esm_embeddings", type=bool, default=True)
    args = parser.parse_args()
    main(**vars(args))
