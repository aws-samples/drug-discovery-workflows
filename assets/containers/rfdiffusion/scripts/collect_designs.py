# Original Copyright 2022 Facebook, Inc. and its affiliates.
# Modifications Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
import jsonlines
import logging
import os
import biotite
from biotite.structure.io import load_structure
from biotite.sequence.io import load_sequences
import uuid

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def merge_seqs(scaffold_seq, generated_seq, design_only_indices):
    new_seq = scaffold_seq
    # mask_seq = list("-"*len(scaffold_seq))
    for idx in design_only_indices:
        new_seq[idx] = generated_seq[idx]
        # mask_seq[idx] = generated_seq[idx]
    # return new_seq, ''.join(mask_seq)
    return str(new_seq)


def parse_seq_label(generated_label):
    labels = generated_label.split(", ")
    return {j[0]: float(j[1]) for j in [label.split("=") for label in labels]}


def main(args):
    design_only_indices = [int(i) - 1 for i in args.design_only_positions.split(" ")]
    scaffold_str = load_structure(args.scaffold_pdb)
    scaffold_seq = biotite.structure.to_sequence(scaffold_str)[0][0]
    logging.info(f"SCAFFOLD:    {scaffold_seq}")
    output = []

    for f in os.scandir(args.seq_dir):
        if f.name.endswith(".fasta") or f.name.endswith(".fa"):
            logging.info(f"Processing {f.path}")
            gen_seqs = load_sequences(f.path).items()
            for i, generated_seq in enumerate(gen_seqs):
                if i > 0:
                    seq_dict = {}
                    seq_dict = parse_seq_label(generated_seq[0])
                    seq_dict["sequence"] = merge_seqs(
                        scaffold_seq, generated_seq[1], design_only_indices
                    )
                    seq_dict["backbone_src"] = f.path
                    seq_dict["scaffold_src"] = args.scaffold_pdb
                    seq_dict["uuid"] = uuid.uuid4().hex
                    output.append(seq_dict)

    with jsonlines.open(args.output_path, mode="w") as writer:
        writer.write_all(output)

    return None


if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "scaffold_pdb",
        help="Path to scaffold pdb file.",
        type=str,
    )
    parser.add_argument(
        "design_only_positions",
        help="List residue ids (1-index) for generated residues.",
        type=str,
    )
    parser.add_argument(
        "--seq_dir",
        help="Path to fasta file dir with generated sequences.",
        type=str,
        default="seqs",
    )
    parser.add_argument(
        "--output_path",
        help="Jsonlines output path.",
        type=str,
        default="output.jsonl",
    )

    args = parser.parse_args()

    main(args)
