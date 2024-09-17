import json, sys, os
import numpy as np
import torch
from typing import Callable, Dict, List
from guided_molecule_gen.optimizer import MoleculeGenerationOptimizer
from guided_molecule_gen.oracles import qed, tanimoto_similarity
from rdkit import Chem
from rdkit.Chem import Descriptors
from rdkit.Contrib.SA_Score import sascorer
import networkx as nx

from bionemo.model.core.controlled_generation import ControlledGenerationPerceiverEncoderInferenceWrapper
from bionemo.model.molecule.molmim.infer import MolMIMInference
from bionemo.utils.hydra import load_model_config

def penalized_logp(smiles_list):
    score_list = []
    for smiles in smiles_list:
        # Convert the SMILES string to RDKit molecule representation
        mol = Chem.MolFromSmiles(smiles, sanitize=True)

        if not mol:
            score_list.append(-100)
        else:
            # Values from 250k ZINC sample referenced in Kusner, et al. (2017)
            logP_mean = 2.4570953396190123
            logP_std = 1.434324401111988
            SA_mean = -3.0525811293166134
            SA_std = 0.8335207024513095
            cycle_mean = -0.0485696876403053
            cycle_std = 0.2860212110245455

            # Get logP value and senthetic accessability scores
            logP = Descriptors.MolLogP(mol)
            SA = -sascorer.calculateScore(mol)

            # Get the list of cycles
            cycle_list = nx.cycle_basis(nx.Graph(Chem.rdmolops.GetAdjacencyMatrix(mol)))

            # Handle
            if len(cycle_list) == 0:
                max_cycle_length = 0
            else:
                max_cycle_length = max([len(cycle) for cycle in cycle_list])

            # Calculate the cycle score
            if max_cycle_length <= 6:
                max_cycle_length = 0
            else:
                max_cycle_length = max_cycle_length - 6

            # Get the cycle score
            cycle_score = -max_cycle_length

            # Normalize scores to 250k set
            normalized_logP = (logP - logP_mean) / logP_std
            normalized_SA = (SA - SA_mean) / SA_std
            normalized_cycle = (cycle_score - cycle_mean) / cycle_std
            score_list.append(normalized_logP + normalized_SA + normalized_cycle)

    return np.array(score_list)

def generate(model, smiles, num_molecules):
    # Define property function mapping
    PROPERTIES: Dict[str, Callable] = {
        "QED": qed,
        "plogP": penalized_logp,
    }

    # Define the scaling factors for each property
    SCALING_FACTORS: Dict[str, float] = {
        "QED": 0.9,
        "plogP": 20,
    }

    # Function to create the oracle
    def create_oracle(
        properties, scaling_factors, property_name: str, sim_threshold: float = 0.4, minimize: bool = False
    ) -> Callable:
        if property_name not in properties.keys():
            raise ValueError(f"property_name {property_name} not in accepted values: {properties}")

        scoring_fun = properties[property_name]
        scaling_factor = scaling_factors[property_name]

        def oracle(smis: List[str], reference: str, **_):
            similarities = tanimoto_similarity(smis, reference)
            similarities = np.clip(similarities / sim_threshold, a_min=None, a_max=1)
            scores = scoring_fun(smis)
            scores = scores / scaling_factor
            if minimize:
                scores = -scores
            return -1 * (similarities + scores)

        return oracle

    smiles = smiles
    num_molecules = int(num_molecules)
    # Configuration parameters
    algorithm="CMA-ES"
    property_type = "QED"
    sim_threshold = 0.4
    minimize = False
    n_steps = 3
    radius = 1.0
    scoring_function = PROPERTIES[property_type]
    opt_function = create_oracle(
        PROPERTIES, SCALING_FACTORS, property_name=property_type, sim_threshold=sim_threshold, minimize=minimize
    )

    # Run appropriate algorithm
    controlled_gen_kwargs = {
        "sampling_method": "beam-search",
        "sampling_kwarg_overrides": {"beam_size": 1, "keep_only_best_tokens": True, "return_scores": False},
    }
    model_wrapped = ControlledGenerationPerceiverEncoderInferenceWrapper(
        model, enforce_perceiver=True, hidden_steps=1, **controlled_gen_kwargs
    )
    if algorithm == "CMA-ES":
        optimizer = MoleculeGenerationOptimizer(
            model_wrapped,
            opt_function,
            smiles,
            popsize=20,  # larger values will be slower but more thorough
            optimizer_args={"sigma": 0.75},
        )

        optimizer.optimize(n_steps)
        generated_smiles = optimizer.generated_smis[0]
    else:
        with torch.no_grad():
            sampler_kwargs = {"beam_size": 1, "keep_only_best_tokens": True, "return_scores": False}
            generated_smiles = model.sample(
                seqs=smiles,
                num_samples=num_molecules,
                scaled_radius=radius,
                sampling_method="beam-search-perturbate",
                **sampler_kwargs,
            )[0]

    scores = scoring_function(generated_smiles).tolist()

    scored_output = [
        {"smiles": smiles_string, "score": score} for smiles_string, score in zip(generated_smiles, scores)
    ]
    output = sorted(scored_output, key=lambda v: v["score"], reverse=not minimize)
    if num_molecules<len(output):
        output = output[:num_molecules]

    for i, s in enumerate(output):
        m = Chem.MolFromSmiles(s['smiles'])
        w = Chem.SDWriter(f'{i+1}.sdf')
        w.write(m)

if __name__ == "__main__":
    nim_cache_path = os.environ.get("NIM_CACHE_PATH")
    bionemo_home = os.environ.get("BIONEMO_HOME")
    checkpoint_path = f"{nim_cache_path}/models/molmim_v1.3/molmim_70m_24_3.nemo"
    cfg = load_model_config(config_name="molmim_infer.yaml", config_path=f"{bionemo_home}/examples/tests/conf/")
    cfg.model.downstream_task.restore_from_path = checkpoint_path
    # Redefine BIONEMO_HOME to tmp directory to handle outputs
    os.environ["BIONEMO_HOME"] = "/tmp/bionemo"
    model = MolMIMInference(cfg, interactive=True)

    with open(sys.argv[1], 'r') as fh:
        lines = fh.readlines()
    smiles = []
    for l in lines:
        s = l.split(' ')[0].strip()
        if len(s)>1 and not s.startswith('SMILE'):
            smiles.append(s)
    generate(model, smiles, sys.argv[2])
