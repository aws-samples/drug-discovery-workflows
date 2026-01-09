#!/usr/bin/env python3
"""
Extract protein sequences from Boltz YAML input file.

This script parses a Boltz YAML input file, extracts all protein sequences,
deduplicates them, and outputs:
1. A FASTA file with unique protein sequences
2. A JSON file mapping chain IDs to sequence hashes
"""

import sys
import json
import hashlib
import argparse
from pathlib import Path
from typing import Dict, List, Tuple

try:
    import yaml
except ImportError:
    print(
        "Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr
    )
    sys.exit(1)


def hash_sequence(sequence: str) -> str:
    """
    Generate a hash for a protein sequence.

    Args:
        sequence: Protein amino acid sequence

    Returns:
        SHA256 hash of the sequence (first 16 characters)
    """
    return hashlib.sha256(sequence.encode()).hexdigest()[:16]


def extract_proteins(yaml_path: str) -> Tuple[Dict[str, str], Dict[str, str]]:
    """
    Extract protein sequences from Boltz YAML input file.

    Args:
        yaml_path: Path to the Boltz YAML input file

    Returns:
        Tuple of (unique_proteins, chain_to_hash) where:
        - unique_proteins: Dict mapping sequence_hash -> (chain_id, sequence)
        - chain_to_hash: Dict mapping chain_id -> sequence_hash

    Raises:
        FileNotFoundError: If YAML file doesn't exist
        yaml.YAMLError: If YAML is malformed
        KeyError: If YAML structure is invalid
        ValueError: If YAML is missing required fields
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

    # Extract proteins
    unique_proteins = {}  # hash -> (first_chain_id, sequence)
    chain_to_hash = {}  # chain_id -> hash

    for seq_entry in data["sequences"]:
        if not isinstance(seq_entry, dict):
            continue

        # Check if this is a protein entry
        if "protein" not in seq_entry:
            continue

        protein = seq_entry["protein"]

        # Validate protein entry
        if not isinstance(protein, dict):
            raise ValueError(f"Invalid protein entry: {protein}")

        if "id" not in protein:
            raise ValueError("Invalid protein entry: Missing 'id' field")

        if "sequence" not in protein:
            chain_ref = protein['id'] if isinstance(protein['id'], str) else protein['id'][0] if isinstance(protein['id'], list) and protein['id'] else "unknown"
            raise ValueError(
                f"Invalid protein entry for chain {chain_ref}: Missing 'sequence' field"
            )

        chain_id = protein["id"]
        sequence = protein["sequence"]
        
        # Handle chain_id as either string or list
        if isinstance(chain_id, list):
            chain_ids = chain_id
        else:
            chain_ids = [chain_id]

        # Validate sequence
        if not sequence or not isinstance(sequence, str):
            raise ValueError(
                f"Invalid sequence for chain {chain_ids}: Sequence must be a non-empty string"
            )

        # Generate hash for this sequence
        seq_hash = hash_sequence(sequence)

        # Store mapping from each chain to hash
        for cid in chain_ids:
            chain_to_hash[cid] = seq_hash

        # Store unique sequences (keep first occurrence with first chain ID)
        if seq_hash not in unique_proteins:
            unique_proteins[seq_hash] = (chain_ids[0], sequence)

    return unique_proteins, chain_to_hash


def write_fasta(unique_proteins: Dict[str, Tuple[str, str]], output_path: str) -> None:
    """
    Write unique protein sequences to FASTA file.

    Args:
        unique_proteins: Dict mapping sequence_hash -> (chain_id, sequence)
        output_path: Path to output FASTA file
    """
    with open(output_path, "w") as f:
        for seq_hash, (chain_id, sequence) in unique_proteins.items():
            f.write(f">{chain_id}\n")
            # Write sequence in 80-character lines (standard FASTA format)
            for i in range(0, len(sequence), 80):
                f.write(f"{sequence[i:i+80]}\n")


def write_protein_map(chain_to_hash: Dict[str, str], output_path: str) -> None:
    """
    Write protein map (chain_id -> sequence_hash) to JSON file.

    Args:
        chain_to_hash: Dict mapping chain_id -> sequence_hash
        output_path: Path to output JSON file
    """
    with open(output_path, "w") as f:
        json.dump(chain_to_hash, f, indent=2)


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Extract protein sequences from Boltz YAML input file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Extract proteins from input.yaml
  python extract_proteins.py input.yaml
  
  # Specify custom output paths
  python extract_proteins.py input.yaml --fasta proteins.fasta --map protein_map.json
        """,
    )

    parser.add_argument("yaml_file", help="Path to Boltz YAML input file")

    parser.add_argument(
        "--fasta",
        default="proteins.fasta",
        help="Output FASTA file path (default: proteins.fasta)",
    )

    parser.add_argument(
        "--map",
        default="protein_map.json",
        help="Output protein map JSON file path (default: protein_map.json)",
    )

    parser.add_argument(
        "--has-proteins-flag",
        default="has_proteins.txt",
        help="Output flag file indicating if proteins were found (default: has_proteins.txt)",
    )

    args = parser.parse_args()

    try:
        # Extract proteins from YAML
        unique_proteins, chain_to_hash = extract_proteins(args.yaml_file)

        # Check if any proteins were found
        has_proteins = len(unique_proteins) > 0

        if has_proteins:
            # Write outputs
            write_fasta(unique_proteins, args.fasta)
            write_protein_map(chain_to_hash, args.map)

            print(
                f"Successfully extracted {len(unique_proteins)} unique protein sequence(s)"
            )
            print(f"Total protein chains: {len(chain_to_hash)}")
            print(f"FASTA file: {args.fasta}")
            print(f"Protein map: {args.map}")
        else:
            print("No protein sequences found in YAML file")
            # Create empty outputs
            Path(args.fasta).touch()
            with open(args.map, "w") as f:
                json.dump({}, f)

        # Write has_proteins flag
        with open(args.has_proteins_flag, "w") as f:
            f.write("true" if has_proteins else "false")

        return 0

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except (yaml.YAMLError, ValueError, KeyError) as e:
        print(f"Error parsing YAML: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
