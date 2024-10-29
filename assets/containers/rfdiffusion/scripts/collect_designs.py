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
import biotite.sequence as seq
import biotite.sequence.io.fasta as fasta
import uuid

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def merge_seqs(scaffold_seq, generated_seq, design_only_indices):
    new_seq = scaffold_seq
    for idx in design_only_indices:
        new_seq[idx] = generated_seq[idx]
    return str(new_seq)


def parse_seq_label(generated_label):
    labels = generated_label.split(", ")
    label_dict = {j[0]: float(j[1]) for j in [label.split("=") for label in labels]}
    return label_dict


def write_seqs_to_jsonlines(seqs) -> None:
    with jsonlines.open(args.output_path + ".jsonl", mode="w") as writer:
        writer.write_all(seqs)
    return None


def write_seqs_to_fasta(seqs) -> None:
    fasta_file = fasta.FastaFile(chars_per_line=150)
    for record in seqs:
        sequence = seq.ProteinSequence(record["sequence"])
        header = record["id"]
        fasta.set_sequence(fasta_file, sequence, header=header)
    print(fasta_file)
    fasta_file.write(args.output_path + ".fa")
    return None


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
                    seq_dict["backbone_src"] = f.name.replace(".fa", ".pdb")
                    seq_dict["scaffold_src"] = args.scaffold_pdb
                    seq_dict["id"] = uuid.uuid4().hex
                    output.append(seq_dict)
            logging.info(f"Processed {i} sequences")


    write_seqs_to_jsonlines(output)
    write_seqs_to_fasta(output)

    return None


if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--scaffold_pdb",
        help="Path to scaffold pdb file.",
        type=str,
    )
    parser.add_argument(
        "--design_only_positions",
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
        help="Output file name (without extension)",
        type=str,
        default="output",
    )

    args = parser.parse_args()

    main(args)
