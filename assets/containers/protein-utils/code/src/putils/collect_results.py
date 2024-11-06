import argparse
import logging
import jsonlines
import os

logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)


def get_collected_results(args):

    rfdiffusion = {}
    logging.info(f"Loading generation results from {args.generation_results}")
    with jsonlines.open(args.generation_results, "r") as reader:
        for obj in reader:
            rfdiffusion[obj["id"]] = obj

    esmfold = {}
    logging.info(f"Loading protein folding results from {args.esmfold_results}")
    with jsonlines.open(args.esmfold_results, "r") as reader:
        for obj in reader:
            obj["esmfold_structure"] = os.path.join(obj["name"] + ".pdb")
            esmfold[obj["name"]] = obj

    ppl = {}
    logging.info(f"Loading pseudo perplexity results from {args.ppl_results}")
    with jsonlines.open(args.ppl_results, "r") as reader:
        for obj in reader:
            ppl[obj["name"]] = obj

    collected_results = []
    logging.info(f"Combining results")

    for obj in rfdiffusion.values():
        print(obj["id"])
        esmfold_record = esmfold[obj["id"]]
        ppl_record = ppl[obj["id"]]
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
                "amplify.pseudo_perplexity": ppl_record["pseudo_perplexity"],
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
        "--ppl_results",
        help="Path to folder containing pseudo perplexity results.",
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
