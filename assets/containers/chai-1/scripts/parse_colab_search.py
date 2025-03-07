import hashlib
from itertools import batched
import logging
import os
import pandas as pd
import re

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)


def get_sequence_hash(seq: str) -> str:
    """Get SHA-256 hash for a text string."""
    return hashlib.sha256(seq.encode()).hexdigest()


def parse_a3m_records(
    records: list[str], source_database: str = "uniref90", paired: bool = False
) -> list:
    output = []

    for i, record in enumerate(batched(records, 2)):
        description = re.match(r">([^|\W]+)", record[0])[1]
        seq = record[1]
        hash = get_sequence_hash(seq)
        db = "query" if i == 0 else source_database
        pairing_key = str(i) if paired else ""
        output.append((seq, db, pairing_key, description, hash))
    return output


def parse_mmseqs2_search_results(
    path: str, source_database: str = "uniref90", paired: bool = False
) -> list[list[tuple]]:
    """Extract sequence data from mmseqs a3m file."""
    parsed_data = []
    logging.info(f"Reading {path}")
    with open(path, "br") as f:
        lines = f.read()
        queries = lines.split(b"\x00")[:-1]
        logging.info(f"Found {len(queries)} query records.")
        for query in queries:
            hits = parse_a3m_records(
                query.decode().rstrip().split("\n"), source_database, paired
            )
            logging.info(f"Parsed {len(hits)-1} hits.")
            parsed_data.append(hits)

    return parsed_data


def write_chai_1_msa(
    output_dir: str, data: list[tuple], parquet: bool = True, csv: bool = False
) -> None:
    """Write a list of lists of tuples to a .aligned.pqt file."""
    df = pd.DataFrame(
        data,
        columns=[
            "sequence",
            "source_database",
            "pairing_key",
            "description",
            "hash",
        ],
    )
    df = df.drop_duplicates(subset=["hash"], keep="first", ignore_index=True)
    root_file_name = os.path.join(output_dir, df.iloc[0]["hash"])
    df = df.drop(columns=["hash"])
    df = df.rename(columns={"description": "comment"})
    logging.info(f"\n {df.head(25)}")

    pqt_name = root_file_name + ".aligned.pqt"

    logging.info(f"Writing {len(df)} records to {pqt_name}")
    df.to_parquet(pqt_name, compression=None)
    if csv:
        csv_name = root_file_name + ".csv"
        logging.info(f"Writing {len(df)} records to {csv_name}")
        df.to_csv(csv_name, compression=None, index=False)

    return None


def main(
    output_dir: str,
    envdb_unpaired_path: str,
    uniref_unpaired_path: str,
    paired_path: str = None,
    parquet: bool = True,
    csv: bool = False,
):
    envdb_unpaired = parse_mmseqs2_search_results(envdb_unpaired_path, "bfd_uniclust")
    uniref_unpaired = parse_mmseqs2_search_results(uniref_unpaired_path, "uniref90")
    if paired_path:
        paired = parse_mmseqs2_search_results(paired_path, paired=True)
        assert len(paired) == len(envdb_unpaired) == len(uniref_unpaired)
    else:
        assert len(envdb_unpaired) == len(uniref_unpaired)

    for i in range(len(uniref_unpaired)):
        logging.info(f"Processing query {i+1} of {len(uniref_unpaired)}")
        if paired_path:
            query_consolidated = (
                paired[i] + envdb_unpaired[i][1:] + uniref_unpaired[i][1:]
            )
        else:
            query_consolidated = envdb_unpaired[i] + uniref_unpaired[i][1:]

        write_chai_1_msa(output_dir, query_consolidated, parquet, csv)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "output_dir",
        type=str,
    )

    parser.add_argument(
        "--envdb_unpaired_path",
        type=str,
    )
    parser.add_argument(
        "--uniref_unpaired_path",
        type=str,
    )
    parser.add_argument(
        "--paired_path",
        type=str,
        required=False,
        default=None,
    )
    parser.add_argument(
        "--parquet",
        type=bool,
        required=False,
        default=True,
    )
    parser.add_argument(
        "--csv",
        type=bool,
        required=False,
        default=False,
    )
    args = parser.parse_args()
    main(**vars(args))
