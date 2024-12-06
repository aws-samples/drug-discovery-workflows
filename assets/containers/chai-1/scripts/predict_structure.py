import argparse
import logging
import numpy as np
from pathlib import Path
import shutil
from chai_lab.chai1 import run_inference

# We use fasta-like format for inputs.
# - each entity encodes protein, ligand, RNA or DNA
# - each entity is labeled with unique name;
# - ligands are encoded with SMILES; modified residues encoded like AAA(SEP)AAA


def main(
    fasta_path,
    device="cuda:0",
    num_diffn_timesteps=200,
    num_trunk_recycles=3,
    output_dir="output",
    seed=None,
    use_esm_embeddings=True,
):

    fasta_path = Path(fasta_path)

    # Inference expects an empty directory; enforce this
    output_dir = Path(output_dir)
    if output_dir.exists():
        logging.warning(f"Removing old output directory: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(exist_ok=True)

    candidates = run_inference(
        fasta_file=fasta_path,
        output_dir=output_dir,
        num_trunk_recycles=num_trunk_recycles,
        num_diffn_timesteps=num_diffn_timesteps,
        seed=seed,
        device=device,
        use_esm_embeddings=use_esm_embeddings,
    )

    cif_paths = candidates.cif_paths
    agg_scores = [rd.aggregate_score.item() for rd in candidates.ranking_data]

    # Load pTM, ipTM, pLDDTs and clash scores for sample 2
    scores = np.load(output_dir.joinpath("scores.model_idx_2.npz"))
    return (cif_paths, agg_scores, scores)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("fasta_path", type=str)
    parser.add_argument("--device", type=str, default="cuda:0")
    parser.add_argument("--num_diffn_timesteps", type=int, default=200)
    parser.add_argument("--num_trunk_recycles", type=int, default=3)
    parser.add_argument("--output_dir", type=str, default="output")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--use_esm_embeddings", type=bool, default=True)
    args = parser.parse_args()
    main(**vars(args))
