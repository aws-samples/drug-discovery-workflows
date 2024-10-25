import argparse
import logging 
import pyfastx

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)

def main(args):
    # TO DO!

    logging.info(f"Calculating fitness for {args.input_file}")
    return None

if __name__ == '__main__':
    
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_file",
        help="Path to input fasta file with sequences to process",
        type=str,
    )

    args = parser.parse_args()
    seqs = [seq for seq in pyfastx.Fasta(args.input_file)]

    main(args)