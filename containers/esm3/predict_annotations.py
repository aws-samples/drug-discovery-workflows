import argparse
import json
import logging
import os
from timeit import default_timer as timer

from esm.models.esm3 import ESM3
from esm.sdk.api import (
    ESM3InferenceClientV1,
    ESMProtein,
    SamplingConfig,
    SamplingTrackConfig,
)

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def parse_args():
    """Parse the arguments."""
    logging.info("Parsing arguments")
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "input",
        type=str,
        help="Path to input .pdb file",
    )

    parser.add_argument(
        "--output_dir",
        type=str,
        default=os.path.join(os.getcwd(), "output"),
        help="Output dir for processed files",
    )

    parser.add_argument(
        "--model_dir",
        type=str,
        default=os.path.join(os.getcwd(), "data", "weights"),
        help="Parent path to pretrained model parameters",
    )

    args, _ = parser.parse_known_args()
    return args


def read_json(input_path):
    """Read a .json file and return the contents as a dictionary."""
    with open(input_path, "r") as f:
        data = json.load(f)
    return data

def main(args):
    start_time = timer()
    output_dir = args.output_dir
    os.makedirs(output_dir, exist_ok=True)
    esm3: ESM3InferenceClientV1 = ESM3.from_pretrained("esm3_open_small")

    protein = ESMProtein.from_pdb(path=args.input)
    protein = esm3.encode(protein)
    single_step_protein = esm3.forward_and_sample(
        protein, SamplingConfig(structure=SamplingTrackConfig(topk_logprobs=2))
    )
    single_step_protein = esm3.decode(single_step_protein.protein_tensor)
    annotations = single_step_protein.function_annotations

    logging.info(f"Output is {annotations}")
    output_path = os.path.join(output_dir, f"annotations.txt")
    logging.info(f"Writing output to {output_path}")

    with open(output_path, "w") as f:
        for annotation in annotations:
            f.write(str(annotation.to_tuple()) + "\n")

    logging.info(f"Total run time: {round(timer() - start_time, 3)} s")
    logging.info("Done")


if __name__ == "__main__":
    args = parse_args()
    main(args)
