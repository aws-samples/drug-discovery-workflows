import argparse
import logging
import jsonlines
import os
import boto3
from pprint import pprint
import statistics

logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)

boto_session = boto3.Session()
omics = boto3.client("omics")
s3 = boto3.client("s3")


def get_run(run_id):
    run_details = omics.get_run(id=run_id)
    duration = run_details["stopTime"] - run_details["startTime"]
    return {
        "id": run_details["id"],
        "name": run_details["name"],
        "arn": run_details["arn"],
        "status": run_details["status"],
        "outputUri": run_details["outputUri"],
        "parameters": run_details["parameters"],
        "startTime": run_details["startTime"],
        "stopTime": run_details["stopTime"],
        "duration_sec": duration.total_seconds(),
        "duration_hr": duration.total_seconds() / 3600,
    }


def s3_to_memory(s3_name, s3_key, session=boto3.Session()):
    """
    Download file from S3 to stream in memory
    """
    s3 = session.resource("s3")
    bucket = s3.Bucket(s3_name)

    return bucket.Object(s3_key).get()["Body"]


def jsonlines_to_list(stream):
    """
    Convert a jsonlines stream to a list of json objects
    """
    results = []
    with stream as f:
        reader = jsonlines.Reader(f)
        for obj in reader:
            results.append(obj)

    return results


def download_jsonlines_from_s3(s3_name, s3_key, session=boto3.Session()):
    """
    Download a jsonlines file from S3 and return a list of json objects
    """
    stream = s3_to_memory(s3_name, s3_key, session)
    return jsonlines_to_list(stream)


def extract_raw_metrics(results):
    metrics = {
        "esmfold.mean_plddt": [],
        "esmfold.ptm": [],
        "proteinmpnn.global_score": [],
        "proteinmpnn.score": [],
        "proteinmpnn.seq_recovery": [],
    }
    for result in results:
        metrics["esmfold.mean_plddt"].append(result["esmfold.mean_plddt"])
        metrics["esmfold.ptm"].append(result["esmfold.ptm"])
        metrics["proteinmpnn.global_score"].append(result["proteinmpnn.global_score"])
        metrics["proteinmpnn.score"].append(result["proteinmpnn.score"])
        metrics["proteinmpnn.seq_recovery"].append(result["proteinmpnn.seq_recovery"])

    return metrics


def calc_mean_metrics(raw_metrics):
    mean_metrics = {}
    for key in raw_metrics.keys():
        mean_metrics[key] = statistics.mean(raw_metrics[key])
    return mean_metrics


def split_s3_path(s3_path):
    path_parts = s3_path.replace("s3://", "").split("/")
    bucket = path_parts.pop(0)
    key = "/".join(path_parts)
    return bucket, key


def get_matching_s3_objects(bucket, prefix="", suffix=""):
    """
    Generate objects in an S3 bucket.

    :param bucket: Name of the S3 bucket.
    :param prefix: Only fetch objects whose key starts with
        this prefix (optional).
    :param suffix: Only fetch objects whose keys end with
        this suffix (optional).
    """
    s3 = boto3.client("s3")
    paginator = s3.get_paginator("list_objects_v2")

    kwargs = {"Bucket": bucket}

    # We can pass the prefix directly to the S3 API.  If the user has passed
    # a tuple or list of prefixes, we go through them one by one.
    if isinstance(prefix, str):
        prefixes = (prefix,)
    else:
        prefixes = prefix

    for key_prefix in prefixes:
        kwargs["Prefix"] = key_prefix

        for page in paginator.paginate(**kwargs):
            try:
                contents = page["Contents"]
            except KeyError:
                break

            for obj in contents:
                key = obj["Key"]
                if key.endswith(suffix):
                    yield obj


def get_matching_s3_keys(bucket, prefix="", suffix=""):
    """
    Generate the keys in an S3 bucket.

    :param bucket: Name of the S3 bucket.
    :param prefix: Only fetch keys that start with this prefix (optional).
    :param suffix: Only fetch keys that end with this suffix (optional).
    """
    for obj in get_matching_s3_objects(bucket, prefix, suffix):
        yield obj["Key"]


def get_metrics_key(bucket, key):
    for key in get_matching_s3_keys(bucket, key):
        if key.endswith("DesignNanobodies/CollectResultsTask/1/1/results.jsonl"):
            return key


def main(args):
    logging.info(f"Loading generation results from {args.run_id}")
    run_info = get_run(args.run_id)
    bucket, key = split_s3_path(run_info["outputUri"])
    key = os.path.join(key, args.run_id)
    results = download_jsonlines_from_s3(
        bucket, get_metrics_key(bucket, key), boto_session
    )
    raw_metrics = extract_raw_metrics(results)
    run_info.update(calc_mean_metrics(raw_metrics))
    pprint(run_info)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--run_id",
        help="AWS HealthOmics run ID",
        type=str,
    )
    args = parser.parse_args()
    main(args)
