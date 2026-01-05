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
    protein_map: Dict[str, str], msa_dir: str
) -> Dict[str, str]:
    """
    Build mapping from sequence hash to MSA file path.

    For each unique sequence (identified by hash), we use the MSA file
    corresponding to the first chain ID that had that sequence.

    Args:
        protein_map: Dict mapping chain_id -> sequence_hash
        msa_dir: Directory containing MSA files

    Returns:
        Dict mapping sequence_hash -> msa_file_path

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

    # Build hash -> MSA path mapping
    hash_to_msa = {}
    for seq_hash, chain_id in hash_to_first_chain.items():
        # MSA files are named by chain ID with .a3m extension
        # Look for the combined MSA file (bfd.mgnify30.metaeuk30.smag30.a3m)
        msa_file = msa_directory / f"{chain_id}.bfd.mgnify30.metaeuk30.smag30.a3m"
        
        # Fallback to uniref.a3m if combined MSA doesn't exist
        if not msa_file.exists():
            msa_file = msa_directory / f"{chain_id}.uniref.a3m"
        
        # Use absolute path for MSA file
        if msa_file.exists():
            hash_to_msa[seq_hash] = str(msa_file.resolve())
        else:
            print(
                f"Warning: MSA file not found for chain {chain_id} (hash {seq_hash})",
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

    parser.add_argument(
        "msa_dir", help="Directory containing MSA files (.a3m format)"
    )

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

        # Build hash to MSA mapping
        hash_to_msa = build_hash_to_msa_mapping(protein_map, args.msa_dir)
        print(f"Found MSA files for {len(hash_to_msa)} unique sequence(s)")

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
