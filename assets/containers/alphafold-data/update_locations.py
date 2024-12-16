# Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import sys
import os
import pathlib
import shutil

from alphafold.data.pipeline_multimer import int_id_to_str_id


def update_locations(target_dir, file_list):
    for filename in file_list:
        # index, _null, outfile = filename.partition("_")
        # index = index.split(".")[1]
        # chain = int_id_to_str_id(int(index))
        [_null, chain, database, file] = filename.split("_")
        outfile = "_".join([database, file])
        # print(f'file: {filename} index: {index} chain: {chain} outfile:{outfile}')
        print(f'file: {filename} chain: {chain} outfile:{outfile}')
        chain = os.path.join(target_dir, chain)
        path = pathlib.Path(chain)


        if not path.exists():
            path.mkdir(parents=True)
        shutil.copy(filename, os.path.join(chain, outfile), follow_symlinks=True)
        

if __name__ == "__main__":
    update_locations(sys.argv[1], sys.argv[2:])
