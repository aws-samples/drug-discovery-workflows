import argparse
import yaml
import os
import biotite.sequence.io.fasta as fasta


def read_boltz_yaml(input_file):
    """Load Boltz-1 yaml input file"""

    with open(input_file, "r") as f:
        data = yaml.safe_load(f)

    return data


def write_boltz_yaml(boltz_input_dict, msa_paths=["test"], output_path="input.yaml"):
    """Create Boltz-1 input yaml file from input dictionary"""

    seqs = []

    for sequence in boltz_input_dict["sequences"]:
        entity_type = list(sequence.keys())[0]
        sequence[entity_type]["id"] = f"[{', '.join(sequence[entity_type]['id'])}]"
        if entity_type == "protein" and msa_paths:
            sequence[entity_type]["msa"] = msa_paths.pop(0)
        seqs.append(sequence)

    boltz_input_dict["sequences"] = seqs
    with open(output_path, "w") as f:
        yaml.dump(boltz_input_dict, f, default_flow_style=False)

    return os.path.abspath(output_path)


def extract_protein_sequences(boltz_input_dict):
    """Extract protein sequences from Boltz-1 input dictionary"""

    fasta_file = fasta.FastaFile()
    for i, sequence in enumerate(boltz_input_dict["sequences"]):
        if "protein" in sequence:
            fasta_file[f"SEQ{i}"] = sequence["protein"]["sequence"]

    with open("protein_sequences.fasta", "w") as f:
        fasta_file.write(f)

    return os.path.abspath("protein_sequences.fasta")


def generate_msa(fasta_path):
    """Use MMSeq2 to generate MSA from protein sequences"""

    with open("msa.a3m", "w") as f:
        f.write("test")

    return [os.path.abspath("msa.a3m")]


def add_msa_paths_to_parsed_input(parsed_input, msa_paths):
    """Add MSA paths to Boltz-1 input dictionary"""

    parsed_input["msa"] = msa_paths

    return parsed_input


def main(input_file):
    parsed_input = read_boltz_yaml(input_file=input_file)
    fasta_path = extract_protein_sequences(parsed_input)
    msa_paths = generate_msa(fasta_path)
    output = write_boltz_yaml(parsed_input, msa_paths)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input_file", help="Boltz input file in YAML format.")
    args = parser.parse_args()
    output_file = main(input_file=args.input_file)
    print(f"Output file: {output_file}")
