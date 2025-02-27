# Copyright (c) 2024 Chai Discovery, Inc.
# Licensed under the Apache License, Version 2.0.
# Modifications copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# See the LICENSE file for details.
import logging
import urllib.request
from pathlib import Path
import os


def download_cif_file(
    pdb_id: str,
    directory: Path,
) -> Path:
    """Download the cif file for the given PDB ID from RCSB into the directory."""
    outfile = directory / f"{pdb_id}.cif.gz"
    if outfile.is_file() and outfile.stat().st_size > 0:
        logging.warning(
            f"Destination for {pdb_id=} already exists: {outfile}; will not overwrite"
        )
        return outfile

    if "PDB_TEMPLATE_DIR" in os.environ:
        pdb_id = pdb_id.lower()
        div = pdb_id[1:3]
        target_path = (
            Path(os.environ["PDB_TEMPLATE_DIR"])
            / "divided"
            / div
            / (pdb_id + ".cif.gz")
        )
        retrieved_path = Path(outfile)
        retrieved_path.symlink_to(target_path)
    else:
        source_url = f"https://files.rcsb.org/download/{pdb_id}.cif.gz"
        logging.info(f"Fetching {source_url} -> {outfile}")
        retrieved, _ = urllib.request.urlretrieve(url=source_url, filename=outfile)
        retrieved_path = Path(retrieved)

    assert retrieved_path == outfile
    assert retrieved_path.exists() and retrieved_path.stat().st_size > 0
    return retrieved_path
