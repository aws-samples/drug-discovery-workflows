import yaml
import argparse

def generate_yaml(args):
    config = {
        # Global
        "max_edit": args.max_edit,
        "noise": args.noise,
        "num_cpus": args.num_cpus,

        # Heavy 
        "GL_target_score_H": args.GL_target_score_H,
        "GL_allow_CDR_mutations_H": args.GL_allow_CDR_mutations_H,
        "GL_fixed_imgt_positions_H": args.GL_fixed_imgt_positions_H,
        "CNN_target_score_H": args.CNN_target_score_H,
        "CNN_allow_CDR_mutations_H": args.CNN_allow_CDR_mutations_H,
        "CNN_fixed_imgt_positions_H": args.CNN_fixed_imgt_positions_H,

        # Light 
        "GL_target_score_L": args.GL_target_score_L,
        "GL_allow_CDR_mutations_L": args.GL_allow_CDR_mutations_L,
        "GL_fixed_imgt_positions_L": args.GL_fixed_imgt_positions_L,
        "CNN_target_score_L": args.CNN_target_score_L,
        "CNN_allow_CDR_mutations_L": args.CNN_allow_CDR_mutations_L,
        "CNN_fixed_imgt_positions_L": args.CNN_fixed_imgt_positions_L,

        # Paired
        "CNN_target_score_P": args.CNN_target_score_P
    }

    with open(args.output, "w") as f:
        yaml.dump(config, f, default_flow_style=False)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate YAML configuration file.")
    parser.add_argument("--max_edit", type=int, default=60)
    parser.add_argument("--noise", type=float, default=0.01)
    parser.add_argument("--num_cpus", type=int, default=16)

    parser.add_argument("--GL_target_score_H", type=float, default=0.40)
    parser.add_argument("--GL_allow_CDR_mutations_H", type=bool, default=False)
    parser.add_argument("--GL_fixed_imgt_positions_H", nargs="*", default=[])

    parser.add_argument("--CNN_target_score_H", type=float, default=0.95)
    parser.add_argument("--CNN_allow_CDR_mutations_H", type=bool, default=False)
    parser.add_argument("--CNN_fixed_imgt_positions_H", nargs="*", default=[])

    parser.add_argument("--GL_target_score_L", type=float, default=0.40)
    parser.add_argument("--GL_allow_CDR_mutations_L", type=bool, default=False)
    parser.add_argument("--GL_fixed_imgt_positions_L", nargs="*", default=[])

    parser.add_argument("--CNN_target_score_L", type=float, default=0.95)
    parser.add_argument("--CNN_allow_CDR_mutations_L", type=bool, default=False)
    parser.add_argument("--CNN_fixed_imgt_positions_L", nargs="*", default=[])

    parser.add_argument("--CNN_target_score_P", type=float, default=0.95)

    parser.add_argument("--output", type=str, default="config.yaml", help="Output YAML file")

    args = parser.parse_args()
    generate_yaml(args)
