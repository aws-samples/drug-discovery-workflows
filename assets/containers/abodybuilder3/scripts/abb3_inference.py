# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
from abodybuilder3.utils import string_to_input, add_atom37_to_output
from abodybuilder3.lightning_module import LitABB3
from abodybuilder3.openfold.np.protein import Protein, to_pdb
from abodybuilder3.openfold.np.relax.cleanup import fix_pdb
import io
import json
import numpy as np
import os
import torch
import logging
import pyfastx
import uuid

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def output_to_pdb(output: dict, model_input: dict) -> str:
    """Generates a pdb file from ABB3 predictions.

    Args:
        output (dict): ABB3 output dictionary
        model_input (dict): ABB3 input dictionary

    Returns:
        str: the contents of a pdb file in string format.
    """
    aatype = model_input["aatype"].squeeze().cpu().numpy().astype(int)
    atom37 = output["atom37"]
    chain_index = 1 - model_input["is_heavy"].cpu().numpy().astype(int)
    atom_mask = output["atom37_atom_exists"].cpu().numpy().astype(int)
    residue_index = np.arange(len(atom37))

    protein = Protein(
        aatype=aatype,
        atom_positions=atom37,
        atom_mask=atom_mask,
        residue_index=residue_index,
        b_factors=np.zeros_like(atom_mask),
        chain_index=chain_index,
    )

    pdb = fix_pdb(io.StringIO(to_pdb(protein)), {})
    return pdb


def compute_plddt(plddt: torch.Tensor) -> torch.Tensor:
    """Computes plddt from the model output. The output is a histogram of unnormalised
    plddt.

    Args:
        plddt (torch.Tensor): (B, n, 50) output from the model

    Returns:
        torch.Tensor: (B, n) plddt scores
    """
    pdf = torch.nn.functional.softmax(plddt, dim=-1)
    vbins = torch.arange(1, 101, 2).to(plddt.device).float()
    output = pdf @ vbins  # (B, n)
    return output

def predict_structure(
    heavy, light, model_path="plddt-loss/best_second_stage.ckpt", output_dir="output"
):
    id = str(uuid.uuid4())
    output_file = os.path.join(output_dir, id + ".pdb")

    logging.info(f"Heavy chain sequence: {heavy}")
    logging.info(f"Light chain sequence: {light}")
    module = LitABB3.load_from_checkpoint(model_path)
    model = module.model
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    ab_input = string_to_input(heavy=heavy, light=light)
    ab_input_batch = {
        key: (
            value.unsqueeze(0).to(device)
            if key not in ["single", "pair"]
            else value.to(device)
        )
        for key, value in ab_input.items()
    }

    model.to(device)

    output = model(ab_input_batch, ab_input_batch["aatype"])
    output = add_atom37_to_output(output, ab_input["aatype"].to(device))

    if "plddt" in output:
        plddt = compute_plddt(output["plddt"]).squeeze().detach().cpu().numpy()
    else:
        plddt = np.zeros(len(ab_input_batch["aatype"]), dtype=np.float)

    b_factors = np.expand_dims(plddt, 1).repeat(37, 1)
    logging.info(f"Writing results to {output_file}")

    aatype = ab_input["aatype"].squeeze().cpu().numpy().astype(int)
    atom37 = output["atom37"]
    chain_index = 1 - ab_input["is_heavy"].cpu().numpy().astype(int)
    atom_mask = output["atom37_atom_exists"].cpu().numpy().astype(int)
    residue_index = np.arange(len(atom37))

    protein = Protein(
        aatype=aatype,
        atom_positions=atom37,
        atom_mask=atom_mask,
        residue_index=residue_index,
        b_factors=b_factors,
        chain_index=chain_index,
    )

    pdb_string = fix_pdb(io.StringIO(to_pdb(protein)), {})

    metrics = {
        "name": id,
        "sequence_heavy": heavy,
        "sequence_light": light,
        "sequence_length": len(heavy),
        "mean_plddt": round(plddt.mean().item(), 3),
    }

    with open(os.path.join(output_dir, id + ".json"), "w") as f:
        json.dump(metrics, f)
        f.write("\n")

    with open(output_file, "w") as f:
        f.write(pdb_string)
    return output_file


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file",
        help="FASTA file containing two amino acid sequences, one for the heavy chain and a second for the light chain.",
        type=str,
    )
    parser.add_argument(
        "--model_path",
        help="Path to model parameters",
        default="plddt-loss/best_second_stage.ckpt",
        type=str,
    )
    parser.add_argument(
        "--output_dir",
        help="(Optional) Path to output dir",
        default="output",
        type=str,
    )

    args = parser.parse_args()
    seqs = [seq[1] for seq in pyfastx.Fasta(args.input_file, build_index=False)]

    logging.info(f"Predicting structure for {args.input_file}")

    predict_structure(
        str(seqs[0]),
        str(seqs[1]),
        args.model_path,
        args.output_dir,
    )
