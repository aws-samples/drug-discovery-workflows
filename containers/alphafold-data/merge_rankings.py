import json
import sys
import os
from argparse import ArgumentParser



def get_ranking_confidence(item):
    return item[1].get('ranking_confidence',0)


def get_metrics_jsons(msa_dirs):
    metrics_dicts = []

    for msa_dir in msa_dirs:
        metrics_path = os.path.join(msa_dir,'metrics.json')
        with open(metrics_path,'r') as f:
            metrics_dicts.append(json.load(f))

    return metrics_dicts


def sort_results(metrics_dicts):
    model_results = {}
    for metrics in metrics_dicts:
        for k, v in metrics['model_results'].items():
            model_results[k] = v

    sorted_results = []
    for i in sorted(model_results.items(), key=get_ranking_confidence, reverse=True):
        i[1]['prediction'] = i[0]
        sorted_results.append(i)

    return sorted_results


def write_results(sorted_results, output_dir):
    rankings_path = os.path.join(output_dir, 'rankings.json')
    with open(rankings_path, 'w') as f:
        json.dump(sorted_results, f, indent=4)


def merge_rankings(msa_dirs, output_dir):
    print (msa_dirs)
    metrics_dicts = get_metrics_jsons(msa_dirs)
    sorted_results = sort_results(metrics_dicts)
    write_results(sorted_results, output_dir)


def main():
    parser = ArgumentParser()
    parser.add_argument("--msa_dirs", nargs='+', required=True)
    parser.add_argument("--output_dir", help="Output directory", required=True)
    args = parser.parse_args()
    merge_rankings(args.msa_dirs, args.output_dir)


if __name__ == "__main__":
    main()