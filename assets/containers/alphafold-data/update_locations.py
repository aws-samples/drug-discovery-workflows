# Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import sys
import os
import pathlib
import shutil

from alphafold.data.pipeline_multimer import int_id_to_str_id

# def int_id_to_str_id(num: int) -> str:
#   """Encodes a number as a string, using reverse spreadsheet style naming.

#   Args:
#     num: A positive integer.

#   Returns:
#     A string that encodes the positive integer using reverse spreadsheet style,
#     naming e.g. 1 = A, 2 = B, ..., 27 = AA, 28 = BA, 29 = CA, ... This is the
#     usual way to encode chain IDs in mmCIF files.
#   """
#   if num <= 0:
#     raise ValueError(f'Only positive integers allowed, got {num}.')

#   num = num - 1  # 1-based indexing.
#   output = []
#   while num >= 0:
#     output.append(chr(num % 26 + ord('A')))
#     num = num // 26 - 1
#   return ''.join(output)


# File lists
# NEW:
# [4ZQK2_uniref90_hits.sto 4ZQK1_uniref90_hits.sto]
# [4ZQK1_mgnify_hits.sto 4ZQK2_mgnify_hits.sto]
# [4ZQK1_uniprot_hits.sto 4ZQK2_uniprot_hits.sto]
# [4ZQK1_bfd_hits.a3m 4ZQK2_bfd_hits.a3m]
# [4ZQK2_pdb_hits.sto 4ZQK1_pdb_hits.sto]

# OLD:
# 5nzz_A_uniref90_hits.sto 5nzz_B_uniref90_hits.sto
# 5nzz_A_mgnify_hits.sto 5nzz_B_mgnify_hits.sto
# 5nzz_A_uniprot_hits.sto 5nzz_B_uniprot_hits.sto
# 5nzz_A_bfd_hits.a3m 5nzz_B_bfd_hits.a3m
# 5nzz_A_pdb_hits.sto 5nzz_B_pdb_hits.sto

STRIP_SUFFIXES = [
   "_uniref90_hits.sto",
   "_mgnify_hits.sto",
   "_uniprot_hits.sto",
   "_bfd_hits.a3m",
   "_pdb_hits.sto"
]

def strip_suffixes(s: str, suffixes: list[str]):
    for suffix in suffixes:
        if s.endswith(suffix):
            return (s[:-len(suffix)], suffix)
    return (s, None)

# target_dir = msa
def update_locations(target_dir, file_list):
    for filename in file_list:

        # strip suffixes from filename
        # e.g. "5nzz_A_uniref90_hits.sto" ->
        # stripped_filename = "5nzz_A"
        # stripped_suffix = _uniref90_hits.sto
        (stripped_filename, stripped_suffix) = strip_suffixes(filename, STRIP_SUFFIXES)
        if stripped_suffix == None:
            raise Exception(f"expected suffixes not found in filename: {filename}")

        # "_uniref90_hits.sto" -> "uniref90_hits.sto"
        outfile = stripped_suffix[1:]

        if "_" in stripped_filename:
            # assume 5nzz_A format
            # chain = A
            chain = stripped_filename[-1].upper()
        else:
            # assume 4ZQK2 format
            # chain = B
            chain = int_id_to_str_id(int(stripped_filename[-1]))

        chain_dir = os.path.join(target_dir, chain)
        chain_dir_path = pathlib.Path(chain_dir)

        if not chain_dir_path.exists():
            chain_dir_path.mkdir(parents=True)
        
        target = os.path.join(chain_dir_path, outfile)
        print(f"COPY {filename} -> {target}")
        shutil.copy(filename, target, follow_symlinks=True)


if __name__ == "__main__":
    update_locations(sys.argv[1], sys.argv[2:])
