# Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import sys
import os
import pathlib
import shutil

from alphafold.data.pipeline_multimer import int_id_to_str_id

# Example file_lists:
#
# [4ZQK.1_uniref90_hits.sto 4ZQK.2_uniref90_hits.sto]
# [4ZQK.2_mgnify_hits.sto 4ZQK.1_mgnify_hits.sto]
# [4ZQK.1_uniprot_hits.sto 4ZQK.2_uniprot_hits.sto]
# [4ZQK.1_bfd_hits.a3m 4ZQK.2_bfd_hits.a3m]
# [4ZQK.1_pdb_hits.sto 4ZQK.2_pdb_hits.sto]
# or
# 4ZQK_simple.1_uniref90_hits.sto 4ZQK_simple.2_uniref90_hits.sto
# 4ZQK_simple.1_mgnify_hits.sto 4ZQK_simple.2_mgnify_hits.sto
# 4ZQK_simple.2_uniprot_hits.sto 4ZQK_simple.1_uniprot_hits.sto
# 4ZQK_simple.2_bfd_hits.a3m 4ZQK_simple.1_bfd_hits.a3m
# 4ZQK_simple.1_pdb_hits.sto 4ZQK_simple.2_pdb_hits.sto


def strip_suffix_str(s: str, suffix: str):
    if s.endswith(suffix):
        return s[: -len(suffix)]
    return None


# target_dir = msa
def update_locations(target_dir, strip_suffix, file_list):
    for filename in file_list:
        # filename = 4ZQK_simple.1_uniref90_hits.sto
        # strip_suffix = _uniref90_hits.sto

        stripped_filename = strip_suffix_str(filename, strip_suffix)
        if stripped_filename == None:
            raise Exception(f"Suffix {strip_suffix} not in {filename}")

        # stripped_filename = 4ZQK_simple.1
        record_inx = int(stripped_filename[-1])  # 1
        outfile = strip_suffix[1:]  # uniref90_hits.sto

        chain = int_id_to_str_id(record_inx)

        chain_dir_path = pathlib.Path(os.path.join(target_dir, chain))

        if not chain_dir_path.exists():
            chain_dir_path.mkdir(parents=True)

        target = os.path.join(chain_dir_path, outfile)
        print(f"COPY {filename} -> {target}")
        shutil.copy(filename, target, follow_symlinks=True)


if __name__ == "__main__":
    update_locations(sys.argv[1], sys.argv[2], sys.argv[3:])
