# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
import biotite.structure as struc
from biotite.structure.io.pdb import PDBFile
import jsonlines
import logging
import os

logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)


def clean_structure(structure):
    structure.res_id = struc.create_continuous_res_ids(
        structure, restart_each_chain=True
    )
    structure[struc.info.standardize_order(structure)]
    structure = structure[struc.filter_canonical_amino_acids(structure)]
    return structure


def to_pdb_string(atom_array):
    return "".join(
        [
            "".join(
                [
                    "ATOM".ljust(4),
                    " " * 2,
                    str(i).rjust(5),
                    " " * 2,
                    atom.atom_name.ljust(4),
                    atom.res_name.rjust(3),
                    " ",
                    atom.chain_id,
                    str(atom.res_id).rjust(4),
                    " " * 4,
                    str(atom.coord[0].round(3)).rjust(8),
                    str(atom.coord[1].round(3)).rjust(8),
                    str(atom.coord[2].round(3)).rjust(8),
                    "1.00".rjust(6),
                    "0.00".rjust(6),
                    " " * 10,
                    atom.element.rjust(2),
                    "\n",
                ]
            )
            for i, atom in enumerate(atom_array, start=1)
        ]
    )


def calc_rmsd(scaffold_pdb, predicted_pdb, output_dir):
    scaffold_file = PDBFile.read(scaffold_pdb)
    scaffold_structure = struc.io.pdb.get_structure(scaffold_file)
    scaffold_structure = clean_structure(
        scaffold_structure[0][scaffold_structure.chain_id == "A"]
    )
    scaffold_backbone = scaffold_structure[
        struc.filter_peptide_backbone(scaffold_structure)
    ]

    predicted_pdb_list = predicted_pdb.split(" ")
    output = []
    for pred in predicted_pdb_list:
        predicted_file = PDBFile.read(pred)
        name = "".join(predicted_file.get_remark("1")).strip()
        predicted_structure = struc.io.pdb.get_structure(predicted_file)
        predicted_structure = clean_structure(predicted_structure[0])
        predicted_backbone = predicted_structure[
            struc.filter_peptide_backbone(predicted_structure)
        ]

        super_predicted_backbone, _, _, _ = struc.superimpose_homologs(
            scaffold_backbone, predicted_backbone
        )
        rmsd = round(struc.rmsd(scaffold_backbone, super_predicted_backbone).item(), 3)
        metrics = {
            "name": name,
            "rmsd": rmsd,
            "scaffold": os.path.basename(scaffold_pdb),
            "predicted": os.path.basename(pred),
        }
        output.append(metrics)
        logging.info(metrics)

    with jsonlines.open(
        os.path.join(output_dir, "additional_results.jsonl"), mode="w"
    ) as writer:
        writer.write_all(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--scaffold_pdb",
        help="Path to pdb file with scaffold structure",
        type=str,
    )
    parser.add_argument(
        "--predicted_pdb",
        help="Path to one or more pdb files with predicted structures",
        type=str,
    )
    parser.add_argument(
        "--output_dir",
        help="Path to output dir",
        default=".",
        type=str,
    )
    args = parser.parse_args()
    calc_rmsd(args.scaffold_pdb, args.predicted_pdb, args.output_dir)
