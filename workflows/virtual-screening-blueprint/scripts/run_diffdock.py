import uuid
import requests
import time
import os
import sys

import nimlib
from nimlib import handler as nimlib_handler
from nimlib import formatter as nimlib_formatter
from nimlib.nim_inference_api_builder.http_api import HttpNIMApiInterface

from tritonclient.utils import *
import tritonclient.http as httpclient

from typing import Any, Union
from data_models import HTTPValidationError, MolecularDockingRequest

MODEL_INPUT = [
    ['ligand_file_bytes',         bytes,    '$ligand'         ],
    ['ligand_file_name',          bytes,    ''                ],
    ['protein_file_bytes',        bytes,    '$protein'        ],
    ['protein_file_name',         bytes,    'protein.pdb'     ],
    ['poses_to_generate',         np.int32, '$num_poses'      ],
    ['no_final_step_noise',       bool,     True              ],
    ['diffusion_steps',           np.int32, '$steps'          ],
    ['diffusion_time_divisions',  np.int32, '$time_divisions' ],
    ['save_diffusion_trajectory', bool,     '$save_trajectory'],
    ['skip_gen_conformer',        bool,     False             ],
    ['is_staged',                 bool,     '$is_staged'      ],
    ['context',                   bytes,    '{}'              ]
]

MODEL_OUTPUT = [
    ['visualizations_files',         str,   'trajectory'         ],
    ['docked_ligand_position_files', str,   'ligand_positions'   ],
    ['pose_confidence',              float, 'position_confidence'],
    ['status',                       str,   'status'             ],
]

MODEL_NAME = "diffdock"
TRITON_TIMEOUT = 4 * 60 * 60

if __name__ == "__main__":
    with open(sys.argv[1], 'r') as fh:
        pdb_lines = fh.readlines()
    protein_lines = []
    for l in pdb_lines:
        if l.startswith("ATOM"):
            protein_lines.append(l.strip())

    with open(sys.argv[2], 'r') as fh:
        smi_lines = fh.readlines()
    smiles_lines = []
    for l in smi_lines:
        if not l.startswith('SMILES'):
            s = l.split(' ')[0]
            smiles_lines.append(s.strip())

    body = MolecularDockingRequest(
        protein='\n'.join(protein_lines),
        ligand='\n'.join(smiles_lines),
        ligand_file_type="txt",
        num_poses=sys.argv[3],
        time_divisions=20,
        num_steps=18
    )

    print("molecular_docking called")

    if body.steps > body.time_divisions:
        raise RequestValidationError('diffusion_steps should be less than or equal to diffusion_time_divisions')

    specs = [_.copy() for _ in MODEL_INPUT]

    for v in specs:
        if type(v[2]) == str and v[2].startswith('$'):
            v[2] = getattr(body, v[2][1:])

    specs[1][2] = f'ligand.{body.ligand_file_type}' # update ligand file name
    inputs = []

    for v in specs:
        d = np.array([[v[2]]]).astype(v[1]).astype(v[1])
        inputs.append(httpclient.InferInput(v[0], d.shape, np_to_triton_dtype(d.dtype)))
        inputs[-1].set_data_from_numpy(d)

    outputs = [httpclient.InferRequestedOutput(v[0]) for v in MODEL_OUTPUT]

    with httpclient.InferenceServerClient("localhost:8080", network_timeout=TRITON_TIMEOUT, connection_timeout=TRITON_TIMEOUT) as client:
        def build_result_field(v, t):
            if t == str:
                v = v.astype(str)

            return v.tolist()

        time_start = time.time()
        response = client.infer(MODEL_NAME, inputs, request_id=str(uuid.uuid1()), outputs=outputs, timeout=TRITON_TIMEOUT)
        print(f"Inference time: {time.time() - time_start} seconds")

        result = {v[2]: build_result_field(response.as_numpy(v[0]), v[1]) for v in MODEL_OUTPUT}
        if len(smiles_lines)>1:
            for i, rs in enumerate(result['status']):
                if rs=='success':
                    for j, v in enumerate(result['ligand_positions'][i]):
                        with open(f"{sys.argv[1].split('.')[0]}-{sys.argv[2].split('.')[0]}-{i}-{j}-score{result['position_confidence'][i][j]}.sdf", 'w') as fh:
                            fh.write(v)
        else:
            if result['status']=='success':
                for i, v in enumerate(result['ligand_positions']):
                    with open(f"{sys.argv[1].split('.')[0]}-{sys.argv[2].split('.')[0]}-score{result['position_confidence'][i]}.sdf", 'w') as fh:
                        fh.write(v)
