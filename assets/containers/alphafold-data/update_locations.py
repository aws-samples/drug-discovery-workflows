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

# NEW NEW:
# [5nl6, 5nl6.1, /Users/john/Documents/Code/nextflow-learning/work/dd/64a9f556e8a9f924448cb6e0b35d88/5nl6.1.fasta]
# [5nl6, 5nl6.2, /Users/john/Documents/Code/nextflow-learning/work/dd/64a9f556e8a9f924448cb6e0b35d88/5nl6.2.fasta]
# [5od9, 5od9.1, /Users/john/Documents/Code/nextflow-learning/work/d4/47cd7ab0ebe06438f83aba70061876/5od9.1.fasta]
# [5od9, 5od9.2, /Users/john/Documents/Code/nextflow-learning/work/d4/47cd7ab0ebe06438f83aba70061876/5od9.2.fasta]

# 5nl6.1_uniref90_hits.sto 5nl6.2_uniref90_hits.sto

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

        # Indexed format: 5nl6.1_uniref90_hits.sto
        # record_id = 5nl6.1
        # outfile = uniref90_hits.sto
        record_id, _null, outfile = filename.partition("_")
        record_inx = int(record_id[-1])

        chain = int_id_to_str_id(record_inx)

        chain_dir_path = pathlib.Path(os.path.join(target_dir, chain))

        if not chain_dir_path.exists():
            chain_dir_path.mkdir(parents=True)
        
        target = os.path.join(chain_dir_path, outfile)
        print(f"COPY {filename} -> {target}")
        shutil.copy(filename, target, follow_symlinks=True)


if __name__ == "__main__":
    update_locations(sys.argv[1], sys.argv[2:])
