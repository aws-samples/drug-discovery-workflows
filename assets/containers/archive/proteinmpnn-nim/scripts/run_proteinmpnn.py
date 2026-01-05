# SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: LicenseRef-NvidiaProprietary
#
# NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
# property and proprietary rights in and to this material, related
# documentation and any modifications thereto. Any use, reproduction,
# disclosure or distribution of this material and related documentation
# without an express license agreement from NVIDIA CORPORATION or
# its affiliates is strictly prohibited.

import sys
from pathlib import Path
from model_defs import API_PATH, ModelInputs, ModelOutputs
from model_utils import run_inference


if __name__ == "__main__":
    inputs=ModelInputs(
        input_pdb=Path(sys.argv[1]).read_bytes(),
        input_pdb_chains=sys.argv[2].split(','),
        num_seq_per_target=int(sys.argv[3])
    )
    filename=sys.argv[1].split('.')[0]
    print(filename)
    with open(f'{filename}.fasta', 'w') as f:
        f.write( run_inference(inputs=inputs).mfasta )