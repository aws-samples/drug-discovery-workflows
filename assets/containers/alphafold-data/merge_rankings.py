import json
import os
import shutil
import glob
from argparse import ArgumentParser


def get_ranking_confidence(item):
    return item[1].get("ranking_confidence", 0)


def get_metrics_jsons(model_dirs):
    metrics_dicts = []

    for model_dir in model_dirs:
        metrics_path = os.path.join(model_dir, "metrics.json")
        with open(metrics_path, "r") as f:
            metrics_dicts.append(json.load(f))

    return metrics_dicts


def sort_results(metrics_dicts):
    model_results = {}
    for metrics in metrics_dicts:
        for k, v in metrics["model_results"].items():
            model_results[k] = v

    sorted_results = []
    for i in sorted(model_results.items(), key=get_ranking_confidence, reverse=True):
        i[1]["prediction"] = i[0]
        sorted_results.append(i[1])

    return sorted_results


def write_results(sorted_results, output_dir):
    rankings_path = os.path.join(output_dir, "rankings.json")
    with open(rankings_path, "w") as f:
        json.dump(sorted_results, f, indent=4)


def merge_rankings(model_dirs, output_dir):
    print(model_dirs)
    metrics_dicts = get_metrics_jsons(model_dirs)
    sorted_results = sort_results(metrics_dicts)
    write_results(sorted_results, output_dir)
    return sorted_results


def copy_top_hit(top_hit, model_dirs, output_dir):
    prediction = top_hit["prediction"]

    files_to_copy = []
    for model_dir in model_dirs:
        files_to_copy.extend(glob.glob(os.path.join(model_dir, "*" + prediction + "*")))

    for filename in files_to_copy:
        file_destination = os.path.join(
            output_dir, "top_hit_" + os.path.basename(filename)
        )
        print("Copying %s to %s" % (filename, file_destination))
        shutil.copy(filename, file_destination, follow_symlinks=True)


def main():
    parser = ArgumentParser()
    parser.add_argument("--model_dirs", nargs="+", required=True)
    parser.add_argument("--output_dir", help="Output directory", required=True)
    args = parser.parse_args()
    sorted_results = merge_rankings(args.model_dirs, args.output_dir)

    # Next find the top performing hit and rearrange outputs
    copy_top_hit(sorted_results[0], args.model_dirs, args.output_dir)


if __name__ == "__main__":
    main()
