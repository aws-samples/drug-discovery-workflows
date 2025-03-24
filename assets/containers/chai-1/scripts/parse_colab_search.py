import biotite.sequence.io.fasta as fasta
from biotite.sequence.io.fasta import FastaFile
import hashlib
from io import StringIO
import logging
import os
import pandas as pd
import re
import typer
from typing_extensions import Annotated

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)

app = typer.Typer(pretty_exceptions_enable=False)


def get_sequence_hash(seq: str) -> str:
    """Get SHA-256 hash for a text string."""
    return hashlib.sha256(seq.encode()).hexdigest()


def parse_a3m_block(
    block: FastaFile, source_database: str = "uniref90", paired: bool = False
) -> tuple[str, list[tuple]]:
    output = []
    for i, (header, seq) in enumerate(block.items()):
        if i == 0:
            query_header = header

        db = "query" if i == 0 else source_database
        pairing_key = str(i) if paired else ""
        description = re.match(r"(\w+)", header)[1]
        hash = get_sequence_hash(seq)
        record = (seq, db, pairing_key, description, hash)
        output.append(record)
    return query_header, output


def parse_mmseqs2_search_results(
    path: str, source_database: str = "uniref90", paired: bool = False
) -> list[list[tuple]]:
    """Extract sequence data from mmseqs a3m file."""
    parsed_data = {}
    logging.info(f"Reading {path}")
    with open(path, "br") as f:
        lines = f.read()
        queries = lines.split(b"\x00")[:-1]
        logging.info(f"Found {len(queries)} query records.")
        for i, query in enumerate(queries):
            logging.info(f"Processing query {i + 1} of {len(queries)}")
            strio = StringIO(query.decode().rstrip())
            block = fasta.FastaFile.read(strio)
            header, hits = parse_a3m_block(block, source_database, paired)
            logging.info(f"Found {len(hits) - 1} hits.")
            if header in parsed_data:
                parsed_data[header].extend(hits)
            else:
                parsed_data[header] = hits

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
    df = df.astype({"sequence": "string"})
    logging.info(f"\n {df.head(25)}")

    pqt_name = root_file_name + ".aligned.pqt"

    if parquet:
        logging.info(f"Writing {len(df)} records to {pqt_name}")
        df.to_parquet(pqt_name, compression=None)
    if csv:
        csv_name = root_file_name + ".csv"
        logging.info(f"Writing {len(df)} records to {csv_name}")
        df.to_csv(csv_name, compression=None, index=False)
    return None


@app.command()
def main(
    output_dir: str,
    envdb_unpaired_path: str,
    uniref_unpaired_path: str,
    paired_path: Annotated[str, typer.Argument()] = None,
    parquet: bool = False,
    csv: bool = False,
):
    envdb_unpaired = parse_mmseqs2_search_results(envdb_unpaired_path, "bfd_uniclust")
    logging.info(f"Processed {len(envdb_unpaired)} envdb queries total")

    uniref_unpaired = parse_mmseqs2_search_results(uniref_unpaired_path, "uniref90")

    logging.info(f"Processed {len(uniref_unpaired)} uniref queries total")

    if paired_path and len(uniref_unpaired) > 1:
        paired = parse_mmseqs2_search_results(paired_path, paired=True)
        logging.info(f"Processed {len(paired)} paired queries total")

        assert len(paired) == len(envdb_unpaired) == len(uniref_unpaired)
    else:
        assert len(envdb_unpaired) == len(uniref_unpaired)

    for query_header in uniref_unpaired.keys():
        logging.info(f"Envdb len {len(envdb_unpaired[query_header])}")
        logging.info(f"Uniref len {len(uniref_unpaired[query_header])}")

        if paired_path and len(uniref_unpaired) > 1:
            logging.info(f"Paired len {len(paired[query_header])}")
            query_consolidated = (
                paired[query_header]
                + envdb_unpaired[query_header][1:]
                + uniref_unpaired[query_header][1:]
            )
        else:
            query_consolidated = (
                envdb_unpaired[query_header] + uniref_unpaired[query_header][1:]
            )
        logging.info(f"consolidated len {len(query_consolidated)}")

        write_chai_1_msa(output_dir, query_consolidated, parquet, csv)


if __name__ == "__main__":
    app()
