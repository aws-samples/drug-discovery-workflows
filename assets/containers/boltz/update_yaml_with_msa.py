#!/usr/bin/env python3
"""
Update Boltz YAML input file with MSA file paths.

This script takes the original Boltz YAML input file, a protein map JSON file,
and a directory containing MSA files, then updates the YAML to include MSA
paths for each protein entry.
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Dict

try:
    import yaml
except ImportError:
    print(
        "Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr
    )
    sys.exit(1)


def load_protein_map(protein_map_path: str) -> Dict[str, str]:
    """
    Load protein map from JSON file.

    Args:
        protein_map_path: Path to protein_map.json file

    Returns:
        Dict mapping chain_id -> sequence_hash

    Raises:
        FileNotFoundError: If protein map file doesn't exist
        json.JSONDecodeError: If JSON is malformed
    """
    map_file = Path(protein_map_path)
    if not map_file.exists():
        raise FileNotFoundError(f"Protein map file not found: {protein_map_path}")

    with open(map_file, "r") as f:
        protein_map = json.load(f)

    if not isinstance(protein_map, dict):
        raise ValueError("Invalid protein map: Must be a dictionary")

    return protein_map


def build_hash_to_msa_mapping(
    protein_map: Dict[str, str], msa_dir: str, chain_to_csv: Dict[str, str]
) -> Dict[str, str]:
    """
    Build mapping from sequence hash to MSA CSV file path.

    For each unique sequence (identified by hash), we use the CSV MSA file
    corresponding to the first chain ID that had that sequence.

    Args:
        protein_map: Dict mapping chain_id -> sequence_hash
        msa_dir: Directory containing MSA files
        chain_to_csv: Dict mapping chain_id -> CSV filename

    Returns:
        Dict mapping sequence_hash -> msa_csv_file_path

    Raises:
        FileNotFoundError: If MSA directory doesn't exist
    """
    msa_directory = Path(msa_dir)
    if not msa_directory.exists():
        raise FileNotFoundError(f"MSA directory not found: {msa_dir}")

    # Build reverse mapping: hash -> first chain_id with that hash
    hash_to_first_chain = {}
    for chain_id, seq_hash in protein_map.items():
        if seq_hash not in hash_to_first_chain:
            hash_to_first_chain[seq_hash] = chain_id

    # Build hash -> MSA CSV path mapping
    hash_to_msa = {}
    for seq_hash, chain_id in hash_to_first_chain.items():
        # Look for the CSV file for this chain
        if chain_id in chain_to_csv:
            csv_filename = chain_to_csv[chain_id]
            msa_file = msa_directory / csv_filename
            
            # Use absolute path for MSA file
            if msa_file.exists():
                # hash_to_msa[seq_hash] = str(msa_file.resolve())
                hash_to_msa[seq_hash] = csv_filename
            else:
                print(
                    f"Warning: CSV MSA file not found for chain {chain_id} (hash {seq_hash})",
                    file=sys.stderr,
                )
        else:
            print(
                f"Warning: No CSV MSA file generated for chain {chain_id} (hash {seq_hash})",
                file=sys.stderr,
            )

    return hash_to_msa


def update_yaml_with_msa(
    yaml_path: str, protein_map: Dict[str, str], hash_to_msa: Dict[str, str]
) -> dict:
    """
    Update Boltz YAML with MSA file paths.

    Args:
        yaml_path: Path to original Boltz YAML input file
        protein_map: Dict mapping chain_id -> sequence_hash
        hash_to_msa: Dict mapping sequence_hash -> msa_file_path

    Returns:
        Updated YAML data structure

    Raises:
        FileNotFoundError: If YAML file doesn't exist
        yaml.YAMLError: If YAML is malformed
        ValueError: If YAML structure is invalid
    """
    # Read and parse YAML file
    yaml_file = Path(yaml_path)
    if not yaml_file.exists():
        raise FileNotFoundError(f"YAML file not found: {yaml_path}")

    try:
        with open(yaml_file, "r") as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise yaml.YAMLError(f"Failed to parse YAML file: {e}")

    # Validate YAML structure
    if not isinstance(data, dict):
        raise ValueError("Invalid YAML: Root element must be a dictionary")

    if "sequences" not in data:
        raise ValueError("Invalid YAML: Missing 'sequences' field")

    if not isinstance(data["sequences"], list):
        raise ValueError("Invalid YAML: 'sequences' must be a list")

    # Update each protein entry with MSA path
    proteins_updated = 0
    for seq_entry in data["sequences"]:
        if not isinstance(seq_entry, dict):
            continue

        # Check if this is a protein entry
        if "protein" not in seq_entry:
            continue

        protein = seq_entry["protein"]

        # Validate protein entry
        if not isinstance(protein, dict):
            continue

        if "id" not in protein:
            continue

        chain_id = protein["id"]

        # Get sequence hash for this chain
        if chain_id not in protein_map:
            print(
                f"Warning: Chain {chain_id} not found in protein map",
                file=sys.stderr,
            )
            continue

        seq_hash = protein_map[chain_id]

        # Get MSA path for this sequence hash
        if seq_hash not in hash_to_msa:
            print(
                f"Warning: No MSA file found for chain {chain_id} (hash {seq_hash})",
                file=sys.stderr,
            )
            continue

        # Add MSA field to protein entry
        protein["msa"] = hash_to_msa[seq_hash]
        proteins_updated += 1

    print(f"Updated {proteins_updated} protein entries with MSA paths")

    return data


def write_yaml(data: dict, output_path: str) -> None:
    """
    Write updated YAML data to file.

    Args:
        data: YAML data structure
        output_path: Path to output YAML file
    """
    with open(output_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)


def write_msa_csvs(chain_to_files: Dict[str, list], msa_dir: str) -> Dict[str, str]:
    """
    Combine split MSA files into chain-specific CSV files.
    
    This function reads all the split A3M files for each chain and combines them
    into a single CSV file with proper indexing:
    - Unpaired sequences (from bfd, uniref files): key = -1
    - Paired sequences (from pair files): key = 0, 1, 2, ... (sequential integers)
    
    Args:
        chain_to_files: Dict mapping chain_id -> list of split MSA filenames
                       Example: {"A": ["A.bfd.a3m", "A.uniref.a3m", "A.pair.a3m"]}
        msa_dir: Directory containing the MSA files
    
    Returns:
        Dict mapping chain_id -> CSV file path
        Example: {"A": "A.msa.csv", "B": "B.msa.csv"}
    """
    msa_directory = Path(msa_dir)
    chain_to_csv = {}
    
    for chain_id, filenames in chain_to_files.items():
        csv_rows = []  # List of (key, sequence) tuples
        pair_index = 0  # Counter for paired sequences
        
        for filename in filenames:
            filepath = msa_directory / filename
            
            # Determine if this is a paired MSA file (contains "pair" in filename)
            is_paired = "pair" in filename.lower()
            
            try:
                # Read the A3M file
                with open(filepath, 'r') as f:
                    lines = f.readlines()
                
                # Parse sequences from A3M format
                current_sequence = []
                for line in lines:
                    line = line.strip()
                    if not line:
                        continue
                    
                    if line.startswith('>'):
                        # Save previous sequence if exists
                        if current_sequence:
                            sequence = ''.join(current_sequence)
                            if is_paired:
                                # Paired sequence: use sequential integer key
                                csv_rows.append((pair_index, sequence))
                                pair_index += 1
                            else:
                                # Unpaired sequence: use -1
                                csv_rows.append((-1, sequence))
                            current_sequence = []
                    else:
                        # Sequence line
                        current_sequence.append(line)
                
                # Don't forget the last sequence
                if current_sequence:
                    sequence = ''.join(current_sequence)
                    if is_paired:
                        csv_rows.append((pair_index, sequence))
                        pair_index += 1
                    else:
                        csv_rows.append((-1, sequence))
                        
            except Exception as e:
                print(f"Warning: Error reading {filename}: {e}", file=sys.stderr)
                continue
        
        # Write CSV file for this chain
        if csv_rows:
            csv_filename = f"{chain_id}.msa.csv"
            csv_filepath = msa_directory / csv_filename
            
            with open(csv_filepath, 'w') as f:
                # Write header
                f.write("key,sequence\n")
                # Write rows
                for key, sequence in csv_rows:
                    f.write(f"{key},{sequence}\n")
            
            chain_to_csv[chain_id] = csv_filename
            print(f"Created {csv_filename} with {len(csv_rows)} sequences ({pair_index} paired, {len(csv_rows) - pair_index} unpaired)")
        else:
            print(f"Warning: No sequences found for chain {chain_id}", file=sys.stderr)
    
    return chain_to_csv


def split_msa_files_by_chain(msa_dir: str) -> Dict[str, list]:
    """Iterate through a dir of .a3m files and split them by chain.

    For example, if you have a folder named "msa" that contains the files
    "bfd.mgnify30.metaeuk30.smag30.a3m" and "uniref.a3m", each of which contains
    the alignment results for 2 query sequences, A and B, the end result should be
    4 new .a3m files (6 total):

    - bfd.mgnify30.metaeuk30.smag30.a3m
    - A.bfd.mgnify30.metaeuk30.smag30.a3m
    - B.bfd.mgnify30.metaeuk30.smag30.a3m
    - uniref.a3m
    - A.uniref.a3m
    - B.uniref.a3m

    Chain IDs can be single characters (A, B), numbers (101, 102), or longer
    strings.

    Note: MMseqs2 a3m files use null bytes as delimiters between chain sections.
    We split on null bytes to separate the chains.

    Args:
        msa_dir: Directory containing MSA files (.a3m format)

    Returns:
        Dict mapping chain_id -> list of file paths for that chain
        Example: {"A": ["A.bfd.mgnify30.metaeuk30.smag30.a3m", "A.uniref.a3m"],
                  "B": ["B.bfd.mgnify30.metaeuk30.smag30.a3m", "B.uniref.a3m"]}
    """
    msa_directory = Path(msa_dir)
    chain_to_files = {}

    if not msa_directory.exists():
        print(f"Warning: MSA directory not found: {msa_dir}", file=sys.stderr)
        return chain_to_files

    # Find all .a3m files in the directory
    a3m_files = list(msa_directory.glob("*.a3m"))

    if not a3m_files:
        print(f"Warning: No .a3m files found in {msa_dir}", file=sys.stderr)
        return chain_to_files

    for a3m_file in a3m_files:
        try:
            # Read file as binary
            with open(a3m_file, "rb") as f:
                content = f.read()

            # Split on null bytes - each section is a separate chain
            sections_bytes = content.split(b"\x00")
            
            # Filter out empty sections
            sections_bytes = [s for s in sections_bytes if s.strip()]
            
            if len(sections_bytes) == 0:
                # Empty file, skip
                print(f"File {a3m_file.name} is empty, skipping")
                continue
            
            if len(sections_bytes) == 1:
                # Single chain file - extract chain ID and process it
                print(f"File {a3m_file.name} contains only one section, processing as single-chain")
                # Process this single section
                sections_bytes = [sections_bytes[0]]

            # Process each section
            for section_bytes in sections_bytes:
                try:
                    # Decode section to text
                    section_text = section_bytes.decode("utf-8")
                    
                    # Extract chain ID from first line (should be >A, >B, etc.)
                    first_line = section_text.split("\n")[0].strip()
                    if not first_line.startswith(">"):
                        print(f"Warning: Section doesn't start with '>' in {a3m_file.name}", file=sys.stderr)
                        continue
                    
                    # Extract chain ID (everything after '>')
                    chain_id = first_line[1:].strip()
                    
                    if not chain_id:
                        print(f"Warning: Empty chain ID in {a3m_file.name}", file=sys.stderr)
                        continue
                    
                    # Create output filename: <chain>.<original_filename>
                    output_filename = f"{chain_id}.{a3m_file.name}"
                    output_path = msa_directory / output_filename
                    
                    # Write section to file
                    with open(output_path, "wb") as f:
                        f.write(section_bytes)
                    
                    line_count = section_text.count("\n") + 1
                    print(f"Created {output_filename} with {line_count} lines")
                    
                    # Add to chain_to_files mapping
                    if chain_id not in chain_to_files:
                        chain_to_files[chain_id] = []
                    chain_to_files[chain_id].append(output_filename)
                    
                except UnicodeDecodeError:
                    print(f"Warning: Could not decode section in {a3m_file.name}", file=sys.stderr)
                    continue

        except Exception as e:
            print(f"Error processing {a3m_file.name}: {e}", file=sys.stderr)
            continue

    return chain_to_files


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Update Boltz YAML input file with MSA file paths",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Update YAML with MSA paths
  python update_yaml_with_msa.py input.yaml protein_map.json msa_dir/
  
  # Specify custom output path
  python update_yaml_with_msa.py input.yaml protein_map.json msa_dir/ --output updated_input.yaml
        """,
    )

    parser.add_argument("yaml_file", help="Path to original Boltz YAML input file")

    parser.add_argument(
        "protein_map", help="Path to protein_map.json file from extract_proteins.py"
    )

    parser.add_argument("msa_dir", help="Directory containing MSA files (.a3m format)")

    parser.add_argument(
        "--output",
        default="updated_input.yaml",
        help="Output YAML file path (default: updated_input.yaml)",
    )

    args = parser.parse_args()

    try:
        # Load protein map
        protein_map = load_protein_map(args.protein_map)
        print(f"Loaded protein map with {len(protein_map)} chain(s)")

        # Split .a3m files by chains
        chain_to_files = split_msa_files_by_chain(args.msa_dir)
        print(chain_to_files)
        # Combine split MSA files into chain-specific CSV files
        chain_to_csv = write_msa_csvs(chain_to_files, args.msa_dir)
        print(chain_to_csv)
        # Build hash to MSA CSV mapping
        hash_to_msa = build_hash_to_msa_mapping(protein_map, args.msa_dir, chain_to_csv)
        print(f"Found MSA CSV files for {len(hash_to_msa)} unique sequence(s)")

        # Update YAML with MSA paths
        updated_data = update_yaml_with_msa(args.yaml_file, protein_map, hash_to_msa)

        # Write updated YAML
        write_yaml(updated_data, args.output)
        print(f"Successfully wrote updated YAML to: {args.output}")

        return 0

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except (yaml.YAMLError, ValueError, json.JSONDecodeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
