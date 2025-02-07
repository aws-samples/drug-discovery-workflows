import yaml
import argparse

def generate_yaml(args):
    config = {
        "mode": "multiple_cdrs",
        "model": {
            "checkpoint": args.checkpoint
        },
        "sampling": {
            "seed": args.seed,
            "sample_structure": args.sample_structure,
            "sample_sequence": args.sample_sequence,
            "cdrs": args.cdrs,
            "num_samples": args.num_samples
        },
        "dataset": {
            "test": {
                "type": "sabdab",
                "summary_path": args.summary_path,
                "chothia_dir": args.chothia_dir,
                "processed_dir": args.processed_dir,
                "split": "test"
            }
        }
    }

    with open(args.output, "w") as f:
        yaml.dump(config, f, default_flow_style=False)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate YAML configuration file.")

    # Model parameters
    parser.add_argument("--checkpoint", type=str, default="./trained_models/codesign_multicdrs.pt")

    # Sampling parameters
    parser.add_argument("--seed", type=int, default=2022)
    parser.add_argument("--sample_structure", type=bool, default=True)
    parser.add_argument("--sample_sequence", type=bool, default=True)
    parser.add_argument("--cdrs", nargs="+", default=["H_CDR1", "H_CDR2", "H_CDR3", "L_CDR1", "L_CDR2", "L_CDR3"])
    parser.add_argument("--num_samples", type=int, default=100)

    # Dataset parameters
    parser.add_argument("--summary_path", type=str, default="./data/sabdab_summary_all.tsv")
    parser.add_argument("--chothia_dir", type=str, default="./data/all_structures/chothia")
    parser.add_argument("--processed_dir", type=str, default="./data/processed")

    parser.add_argument("--output", type=str, default="config.yaml", help="Output YAML file")

    args = parser.parse_args()
    generate_yaml(args)
