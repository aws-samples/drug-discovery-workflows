import argparse
import logging
import os
import pyfastx
import random
import shutil
import tempfile
import tqdm
from urllib.parse import urlparse

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def parse_args():
    """Parse the arguments."""
    logging.info("Parsing arguments")
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "source",
        type=str,
        help="Path to input .fasta or .fasta.gz file, e.g. s3://myfasta.fa, http://myfasta.fasta.gz, ~/myfasta.fasta, etc",
    )

    parser.add_argument(
        "--max_records_per_partition",
        type=int,
        default=2000000,
        help="Max number of sequence records per csv partition",
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default=os.getcwd(),
        help="Output dir for processed files",
    )
    parser.add_argument(
        "--save_csv",
        "-c",
        action="store_true",
        default=False,
        help="Save csv files to output dir?",
    )
    parser.add_argument(
        "-f",
        "--save_fasta",
        action="store_true",
        default=False,
        help="Save FASTA file to output dir?",
    )
    parser.add_argument(
        "--shuffle",
        "-s",
        action="store_true",
        default=True,
        help="Shuffle the records in each csv partition?",
    )

    args, _ = parser.parse_known_args()
    return args


def main(args):
    """Transform fasta file into dataset"""

    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)

    tmp_dir = tempfile.TemporaryDirectory(dir=os.getcwd())
    input_file = os.path.join(tmp_dir.name, "input.fa")
    input_path = download(args.source, input_file)

    output_path = split_fasta(
        fasta_file=input_path,
        output_dir=args.output_dir,
        max_records_per_partition=args.max_records_per_partition,
        shuffle=args.shuffle,
        save_fasta=args.save_fasta,
        save_csv=args.save_csv,
    )

    tmp_dir.cleanup()
    logging.info(f"Files saved to {args.output_dir}")

    return output_path


def download(source: str, filename: str) -> str:
    output_dir = os.path.dirname(filename)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    if source.startswith("s3"):
        import boto3

        logging.info(f"Downloading {source} to {filename}")
        s3 = boto3.client("s3")
        parsed = urlparse(source, allow_fragments=False)
        bucket = parsed.netloc
        key = parsed.path[1:]
        total = s3.head_object(Bucket=bucket, Key=key)["ContentLength"]
        tqdm_params = {
            "desc": source,
            "total": total,
            "miniters": 1,
            "unit": "B",
            "unit_scale": True,
            "unit_divisor": 1024,
        }
        with tqdm.tqdm(**tqdm_params) as pb:
            s3.download_file(
                parsed.netloc,
                parsed.path[1:],
                filename,
                Callback=lambda bytes_transferred: pb.update(bytes_transferred),
            )
    elif source.startswith("http"):
        import requests

        logging.info(f"Downloading {source} to {filename}")

        with open(filename, "wb") as f:
            with requests.get(source, stream=True, timeout=60) as r:
                r.raise_for_status()
                total = int(r.headers.get("content-length", 0))

                tqdm_params = {
                    "desc": source,
                    "total": total,
                    "miniters": 1,
                    "unit": "B",
                    "unit_scale": True,
                    "unit_divisor": 1024,
                }
                with tqdm.tqdm(**tqdm_params) as pb:
                    for chunk in r.iter_content(chunk_size=8192):
                        pb.update(len(chunk))
                        f.write(chunk)
    elif os.path.isfile(source):
        logging.info(f"Copying {source} to {filename}")
        shutil.copyfile(source, filename)
    else:
        raise ValueError(f"Invalid source: {source}")

    return filename


def split_fasta(
    fasta_file: str,
    output_dir: str = os.getcwd(),
    max_records_per_partition=2000000,
    shuffle=True,
    save_fasta: bool = True,
    save_csv: bool = False,
) -> list:
    """Split a .fasta or .fasta.gz file into multiple files."""

    # if save_fasta and not os.path.exists(os.path.join(output_dir, "fasta")):
    #     os.makedirs(os.path.join(output_dir, "fasta"))

    # if save_csv and not os.path.exists(os.path.join(output_dir, "csv")):
    #     os.makedirs(os.path.join(output_dir, "csv"))

    print(f"Splitting {fasta_file}")
    fasta_list = []
    fasta_idx = 0

    for i, seq in tqdm.tqdm(
        enumerate(
            pyfastx.Fasta(fasta_file, build_index=False, uppercase=True, full_name=True)
        )
    ):
        fasta_list.append(seq)

        if (i + 1) % max_records_per_partition == 0:
            if shuffle:
                random.shuffle(fasta_list)
            fasta_idx = int(i / max_records_per_partition)
            if save_fasta:
                write_seq_record_to_fasta(fasta_list, output_dir, fasta_idx)
            if save_csv:
                write_seq_record_to_csv(fasta_list, output_dir, fasta_idx)
            fasta_list = []
        else:
            if save_fasta:
                write_seq_record_to_fasta(fasta_list, output_dir, fasta_idx + 1)
            if save_csv:
                write_seq_record_to_csv(fasta_list, output_dir, fasta_idx + 1)
    return output_dir


def write_seq_record_to_fasta(content_list, output_dir, index):
    output_path = os.path.join(
        output_dir,
        f"x{str(index).rjust(3, '0')}.fasta",
    )
    logging.info(f"Writing {output_path}")

    with open(output_path, "w") as f:
        for record in content_list:
            f.write(f">{record[0]}\n{record[1]}\n")
    return output_path


def write_seq_record_to_csv(content_list, output_dir, index):
    output_path = os.path.join(output_dir, f"x{str(index).rjust(3, '0')}.csv")
    logging.info(f"Writing {output_path}")
    with open(output_path, "w") as f:
        f.write(f"id,text\n")
        for record in content_list:
            f.write(f"{record[0].replace(',','')},{record[1].replace(',','')}\n")
    return output_path


if __name__ == "__main__":
    args = parse_args()
    main(args)
