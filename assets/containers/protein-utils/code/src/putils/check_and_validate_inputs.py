import argparse
import logging
# from numpy.polynomial import Polynomial
from Bio import SeqIO
import json
import re

logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)

def write_seq_file(seq, filename):
    with open(filename, "w") as out_fh:
        SeqIO.write(seq, out_fh, "fasta")

def split_and_get_sequence_metrics(target_id, seq_list, output_prefix):
    seq_length = 0
    seq_count = 0
    total_length = 0

    if output_prefix:
        output_prefix = output_prefix + "_"
    else:
        output_prefix = "input_"

    for seq_record in seq_list:
        seq_length += len(seq_record.seq)
        seq_count += 1
        # id = seq_record.id

    write_seq_file(seq_list, "inputs.fasta")

    total_length += seq_length
    return seq_count, total_length


def check_inputs(target_id, fasta_path, output_prefix):
    with open(fasta_path, "r") as in_fh:
        seq_list = list(SeqIO.parse(in_fh, "fasta"))

    seq_count, total_length = split_and_get_sequence_metrics(target_id, seq_list, output_prefix)

    seq_info = {
        "target_id": str(target_id),
        "total_length": str(total_length),
        "seq_count": str(seq_count)
    }

    # write the sequence info to a json file      
    with open("seq_info.json", "w") as out_fh:
        json.dump(seq_info, out_fh)
    # return seq_info
    # return f'{total_length}\n{seq_count}\n'
    return total_length


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--target_id",
        help="The ID of the target",
        type=str,
        required=True
    ) 

    parser.add_argument(
        "--fasta_path",
        help="Path to input FASTA file",
        type=str,
        required=True
    ) 
    parser.add_argument(
        "--output_prefix",
        help="(Optional) file name prefix for the sequence files",
        default=None,
        type=str,
        required=False
    )

    args = parser.parse_args()
    output = check_inputs(args.target_id, args.fasta_path, args.output_prefix)
    print(output)
