import argparse
import logging
import json
import jsonlines
import os

logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)


def get_collected_results(args):
    logging.info(f"Loading generation results from {args.generation_results}")

    esm = {}
    path  = args.esmfold_results
    logging.info(f"Processing {path}")
    with jsonlines.open(args.esmfold_results, "r") as reader:
        for obj in reader:
            logging.info(obj)
            esmfold_results = obj
            esmfold_results.pop("sequence", None)
            esmfold_results.pop("sequence_length", None)
            esmfold_results.pop("max_predicted_aligned_error", None)
            esmfold_results["esmfold_structure"] = os.path.join(
                esmfold_results["name"] + ".pdb"
            )
            esm[esmfold_results["name"]] = esmfold_results

    collected_results = []
    with jsonlines.open(args.generation_results, "r") as reader:
        for obj in reader:
            esmfold_record = esm[obj["id"]]
            collected_results.append(
                {
                    "id": obj["id"],
                    "sequence": obj["sequence"],
                    "rfdiffusion.backbone_pdb": obj["backbone_src"],
                    "proteinmpnn.score": obj["score"],
                    "proteinmpnn.global_score": obj["global_score"],
                    "proteinmpnn.seq_recovery": obj["seq_recovery"],
                    "esmfold.mean_plddt": esmfold_record["mean_plddt"],
                    "esmfold.ptm": esmfold_record["ptm"],
                    "esmfold.structure": esmfold_record["esmfold_structure"],
                }
            )
    logging.info(f"Collected {len(collected_results)} results")
    logging.info(collected_results)
    return collected_results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--generation_results",
        help="Path to jsonlines files containing sequence generation information",
        type=str,
    )
    parser.add_argument(
        "--esmfold_results",
        help="Path to folder containing ESMFold results.",
        type=str,
    )
    parser.add_argument(
        "--output_file",
        help="Path to output file",
        default="results.jsonl",
        type=str,
    )
    args = parser.parse_args()
    results = get_collected_results(args)
    with jsonlines.open(args.output_file, mode="w") as writer:
        writer.write_all(results)
