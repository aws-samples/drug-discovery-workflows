import argparse
from ImmuneBuilder import NanoBodyBuilder2
import logging
import os
import pyfastx
import uuid

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def predict_structure(
    heavy,
    weights_dir=os.getcwd(),
    output_file=str(uuid.uuid4()) + ".pdb",
):
    logging.info(f"Heavy chain sequence: {heavy}")
    predictor = NanoBodyBuilder2(weights_dir=weights_dir)
    sequence_dict = {"H": heavy}

    logging.info(f"Running predictions")
    nanobody = predictor.predict(sequence_dict)

    logging.info(f"Writing results to {output_file}")
    nanobody.save(output_file)

    return output_file


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file",
        help="FASTA file containing a single amino acid sequence for the nanobody heavy chain",
        type=str,
    )
    parser.add_argument(
        "--weights_dir",
        help="Path to model parameters",
        default=os.getcwd(),
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
        args.weights_dir,
        args.output_file,
    )
