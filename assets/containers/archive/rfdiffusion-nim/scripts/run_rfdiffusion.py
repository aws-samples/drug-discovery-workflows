#!/usr/bin/env python3

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
import time

if __name__ == "__main__":
	for i in range(int(sys.argv[2])):
	    inputs=ModelInputs(
	        input_pdb=Path(sys.argv[1]).read_bytes(),
	        contigs=sys.argv[3],
	        diffusion_steps=50,
	    )

	    st = time.time()
	    print(f"RFdiffusion started at: {st}")
	    result = run_inference(inputs=inputs)
	    et = time.time()
	    elapsed_time = et - st
	    print(f"RFdiffusion ended at: {et}; it took: {elapsed_time}")

	    with open(f'design_{i}.pdb', 'w') as f:
	        f.write( result.output_pdb )