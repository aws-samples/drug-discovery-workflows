import argparse
from abodybuilder3.utils import string_to_input, output_to_pdb, add_atom37_to_output
from abodybuilder3.lightning_module import LitABB3
import torch
import logging
import pyfastx
import uuid

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def predict_structure(
    heavy,
    light,
    model_path="plddt-loss/best_second_stage.ckpt",
    output_file=str(uuid.uuid4()) + ".pdb",
):
    logging.info(f"Heavy chain sequence: {heavy}")
    logging.info(f"Light chain sequence: {light}")
    module = LitABB3.load_from_checkpoint(model_path)
    model = module.model
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    ab_input = string_to_input(heavy=heavy, light=light)
    ab_input_batch = {
        key: (
            value.unsqueeze(0).to(device)
            if key not in ["single", "pair"]
            else value.to(device)
        )
        for key, value in ab_input.items()
    }

    model.to(device)

    output = model(ab_input_batch, ab_input_batch["aatype"])
    output = add_atom37_to_output(output, ab_input["aatype"].to(device))
    logging.info(f"Writing results to {output_file}")
    with open(output_file, "w") as f:
        f.write(output_to_pdb(output, ab_input))
    return output_file


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file",
        help="FASTA file containing two amino acid sequences, one for the heavy chain and a second for the light chain.",
        type=str,
    )
    parser.add_argument(
        "--model_path",
        help="Path to model parameters",
        default="plddt-loss/best_second_stage.ckpt",
        type=str,
    )
    parser.add_argument(
        "--output_file",
        help="Output file name.",
        default=str(uuid.uuid4()) + ".pdb",
        type=str,
    )

    args = parser.parse_args()
    seqs = [seq[1] for seq in pyfastx.Fasta(args.input_file, build_index=False)]

    logging.info(f"Predicting structure for {args.input_file}")

    predict_structure(
        str(seqs[0]),
        str(seqs[1]),
        args.model_path,
        args.output_file,
    )
