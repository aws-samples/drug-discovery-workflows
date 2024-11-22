import argparse
from ImmuneBuilder import NanoBodyBuilder2
import json
import logging
import os
import pyfastx
from tqdm import tqdm

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def predict_structures(seqs, weights_dir=os.getcwd(), output_dir="output"):
    logging.info(f"Predicting structures for {len(seqs)} sequences")
    for n, seq in tqdm(
        enumerate(seqs),
        desc=f"Generating structures",
    ):
        logging.info(f"Sequence {n+1} of {len(seqs)}")
        metrics = {
            "name": seq.name,
            "sequence": seq.seq,
            "sequence_length": len(seq.seq),
        }

        predictor = NanoBodyBuilder2(weights_dir=weights_dir)
        sequence_dict = {"H": seq.seq}

        logging.info(f"Running predictions")
        nanobody = predictor.predict(sequence_dict)

        output_file = os.path.join(output_dir, seq.name + ".pdb")
        logging.info(f"Writing results to {output_file}")
        nanobody.save(output_file)
        header_str = f"REMARK   1\nREMARK   1 {seq.name}\n"
        with open(output_file, 'r+') as f:
            content = f.read()
            f.seek(0, 0)
            f.write(header_str + content)

        mean_error = nanobody.error_estimates.mean().item()
        logging.info(f"Mean error is {mean_error}")

        metrics.update(
            {
                "mean_error": round(mean_error, 3),
            }
        )
        with open(os.path.join(output_dir, seq.name + ".json"), "w") as f:
            json.dump(metrics, f)
            f.write("\n")


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
        "--output_dir",
        help="(Optional) Path to output dir",
        default="output",
        type=str,
    )

    args = parser.parse_args()
    seqs = [seq for seq in pyfastx.Fasta(args.input_file)]

    logging.info(f"Predicting structure for {args.input_file}")

    predict_structures(
        seqs,
        args.weights_dir,
        args.output_dir,
    )
