import uuid
import requests
import time
import logging
logger = logging.getLogger(__name__)
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

    with open(sys.argv[2], 'r') as fh:
        sdf_lines = fh.readlines()

    protein_lines = []
    for l in pdb_lines:
        if l.startswith("ATOM"):
            protein_lines.append(l)

    body = MolecularDockingRequest(
        protein='\\\n'.join(protein_lines),
        ligand='\\\n'.join(sdf_lines),
        ligand_file_type="sdf",
        num_poses=sys.argv[3]
    )	

    logger.info("molecular_docking called")

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
        logger.debug(v[0] + " = " + (str(v[2]) if len(str(v[2]))<24 else str(v[2]).replace('\n',' ')[:18] + "..."))

    outputs = [httpclient.InferRequestedOutput(v[0]) for v in MODEL_OUTPUT]

    with httpclient.InferenceServerClient("localhost:8080", network_timeout=TRITON_TIMEOUT, connection_timeout=TRITON_TIMEOUT) as client:
        def build_result_field(v, t):
            if t == str:
                v = v.astype(str)

            return v.tolist()

        time_start = time.time()
        response = client.infer(MODEL_NAME, inputs, request_id=str(uuid.uuid1()), outputs=outputs, timeout=TRITON_TIMEOUT)
        logger.debug(f"Inference time: {time.time() - time_start} seconds")

        result = {v[2]: build_result_field(response.as_numpy(v[0]), v[1]) for v in MODEL_OUTPUT}
        result['protein'] = body.protein
        result['ligand'] = body.ligand
        for i, v in enumerate(result):
        	with open(f"{sys.argv[1].split('.')[0]}-{sys.argv[2].split('.')[0]}-{i}.json", 'w') as fh:
        		fh.write(v)
