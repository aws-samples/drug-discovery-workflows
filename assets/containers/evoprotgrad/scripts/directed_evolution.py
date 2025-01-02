# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import argparse
from argparse import Namespace
import json
import os
import logging
from tqdm import tqdm

import torch
import evo_prot_grad
from evo_prot_grad.models import plm_regressor as plmr
from transformers import AutoModel, EsmForMaskedLM, AutoModelForMaskedLM, AutoTokenizer
import numpy as np
from typing import List, Tuple, Optional
import pandas as pd
from s3_utils import download_s3_folder

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)

def _parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "seed_seq", help="Seed sequence to evolve", type=str
    )
    parser.add_argument(
        "seed_id", help="Id for the seed sequence, used to name output file", type=str
    )
    parser.add_argument(
        "output_path", help="file path for output files", type=str
    )
    parser.add_argument(
        "--plm_expert_name_or_path",
        help="Protein language model to use, specify 'None' to skip",
        default="chandar-lab/AMPLIFY_350M",
        type=str,
    )
    parser.add_argument(
        "--bert_expert_name_or_path",
        help="Bert model to use, specify 'None' to skip",
        default="None",
        type=str,
    )
    parser.add_argument(
        "--onehot_scorer_expert_name_or_path",
        help="OnehotCNN-based property scoring model to use, specify 'None' to skip",
        default='None',
        type=str,
    )
    parser.add_argument(
        "--plm_scorer_expert_name_or_path",
        help="PLM-based property scoring model to use, specify 'None' to skip",
        default='None',
        type=str,
    )
    parser.add_argument(
        "--plm_scorer_num_labels",
        help="Number of outputs generated by the PLM-based property scoring model",
        default=None,
        type=str,
    )
    parser.add_argument(
        "--output_type",
        help="Output type, can be 'best', 'last', or 'all' variants",
        default="all",
        type=str,
    )
    parser.add_argument(
        "--parallel_chains",
        help="Number of MCMC chains to run in parallel",
        default=5,
        type=int,
    )
    parser.add_argument(
        "--n_steps",
        help="Number of MCMC steps per chain",
        default=20,
        type=int,
    )
    parser.add_argument(
        "--max_mutations",
        help="maximum number of mutations per variant",
        default=10,
        type=int,
    )
    parser.add_argument(
        '--verbose', 
        action='store_true', 
        help='Enable verbose output'
    )
    parser.add_argument('--preserved_regions',
                        help="Regions not to mutate, list of tuples",
                        default=None,
                        type=list,
    )
    return parser.parse_known_args()


def get_expert_list(args):
    '''
    Define the chain of experts to run directed evolution with.
    '''
    ## TODO: figure out a way to auto determine OR add a parameter for the intended order of the experts
    ## TODO: currently all temperature is set to `1.0`. add a parameter for "temperature" to determine the importance of EACH expert
    device = "cuda" if torch.cuda else "cpu"
    expert_list = []
    ## TODO: currently supporting only one "generator" model in the chain of experts, 
    # need to figure out if can support multiple at the same time
    assert ((args.plm_expert_name_or_path != 'None') ^ (args.bert_expert_name_or_path != 'None')),\
        "Currently support ONLY ONE generator model (e.g. EITHER ESM or Bert) in the expert chain"
    if args.plm_expert_name_or_path != "None":
        if args.plm_expert_name_or_path.startswith('s3://'):
            # if model files are stored on s3, download them into container
            plm_mdl_dir = os.path.join(os.environ['TMPDIR'], 
                                       os.path.basename(os.path.dirname(args.plm_expert_name_or_path)))
            if not os.path.exists(plm_mdl_dir):
                os.mkdir(plm_mdl_dir)
            print('Downloading pLM model files from s3 to', plm_mdl_dir)
            download_s3_folder(args.plm_expert_name_or_path, plm_mdl_dir)
            print(os.listdir(plm_mdl_dir))
        else:
            plm_mdl_dir = args.plm_expert_name_or_path
        # Load the pLM model and tokenizer as the expert
        if 'esm' in plm_mdl_dir.lower():
            model = EsmForMaskedLM.from_pretrained(plm_mdl_dir, trust_remote_code=True)
            plm_expert = evo_prot_grad.get_expert(
                'esm',
                model=model,
                tokenizer=AutoTokenizer.from_pretrained(plm_mdl_dir, trust_remote_code=True),
                scoring_strategy = 'mutant_marginal',
                temperature=1.0,
                device=device
            )
        elif 'amplify' in plm_mdl_dir.lower():
            model = AutoModel.from_pretrained(plm_mdl_dir, trust_remote_code=True)
            plm_expert = evo_prot_grad.get_expert(
                'amplify',
                model=model,
                tokenizer=AutoTokenizer.from_pretrained(plm_mdl_dir, trust_remote_code=True),
                scoring_strategy='mutant_marginal',
                temperature=1.0,
                device=device
            )
        else:
            raise ValueError("Only implemented experts for ESM2 and Amplify pLMs")
        expert_list.append(plm_expert)
    elif args.bert_expert_name_or_path != "None":
        bert_expert = evo_prot_grad.get_expert(
            'bert',
            scoring_strategy='pseudolikelihood_ratio', 
            temperature=1.0,
            model=AutoModel.from_pretrained(args.bert_expert_name_or_path, trust_remote_code=True),
            device=device
        )
        expert_list.append(bert_expert)
    
    if args.onehot_scorer_expert_name_or_path != "None":
        if args.onehot_scorer_expert_name_or_path.startswith('s3://'):
            # if model files are stored on s3, download them into container
            onehot_scorer_mdl_dir = os.path.join(os.environ['TMPDIR'], 
                                          os.path.basename(os.path.dirname(args.onehot_scorer_expert_name_or_path)))
            if not os.path.exists(onehot_scorer_mdl_dir):
                os.mkdir(onehot_scorer_mdl_dir)
            print('Downloading onehot scorer model files from s3 to', onehot_scorer_mdl_dir)
            download_s3_folder(args.onehot_scorer_expert_name_or_path, onehot_scorer_mdl_dir)
            print(os.listdir(onehot_scorer_mdl_dir))
        else:
            onehot_scorer_mdl_dir = args.onehot_scorer_expert_name_or_path
        
        onehot_scorer_expert = evo_prot_grad.get_expert(
            'onehot_downstream_regression',
            scoring_strategy='attribute_value',
            temperature=1.0,
            model=AutoModel.from_pretrained(onehot_scorer_mdl_dir, trust_remote_code=True),
            device=device
        )
        expert_list.append(onehot_scorer_expert)
        
    if args.plm_scorer_expert_name_or_path != "None":
        assert args.plm_scorer_num_labels, "Must provide number of outputs for plm scorer model"
        if args.plm_scorer_expert_name_or_path.startswith('s3://'):
            # if model files are stored on s3, download them into container
            plm_scorer_mdl_dir = os.path.join(os.environ['TMPDIR'],
                                          os.path.basename(os.path.dirname(args.plm_scorer_expert_name_or_path)))
            if not os.path.exists(plm_scorer_mdl_dir):
                os.mkdir(plm_scorer_mdl_dir)
            print('Downloading onehot scorer model files from s3 to', plm_scorer_mdl_dir)
            download_s3_folder(args.plm_scorer_expert_name_or_path, plm_scorer_mdl_dir)
            print(os.listdir(plm_scorer_mdl_dir))
        else:
            plm_scorer_mdl_dir = args.plm_scorer_expert_name_or_path
        model_cfg = Namespace(
            class_name='SequenceRegressionModel',
            pretrained_ckpt_path=plm_scorer_mdl_dir,
            num_labels=args.plm_scorer_num_labels,
            dropout=0.0,
            no_pretrain=False
        )
        trainer = Namespace(
            is_global_zero=True,
            precision='bf16',
            strategy=None
        )
        tokenizer = AutoTokenizer.from_pretrained(plm_scorer_mdl_dir, trust_remote=True)
        # initialize and load the model
        plmr_model = plmr.model_init_fn(trainer, model_cfg)
        plmr_model = plmr_model.eval()
        plm_scorer_expert = evo_prot_grad.get_expert(
            'plm_downstream_regression',
            scoring_strategy='attribute_value',
            temperature=1.0,
            model=plmr_model,
            tokenizer=tokenizer,
            device=device
        )
        expert_list.append(plm_scorer_expert)
    
    return expert_list
        

def run_evo_prot_grad(args):
    '''
    Run the specified expert pipeline on the seed sequence to evolve it. 
    '''
    # raw_protein_sequence = args.seed_seq
    # fasta_format_sequence = f">Input_Sequence\n{raw_protein_sequence}"

    # # write the mock FASTA string to a temporary file
    # temp_fasta_path = "./temp_input_sequence.fasta"
    # with open(temp_fasta_path, "w") as file:
    #     file.write(fasta_format_sequence)

    expert_list = get_expert_list(args)
    print(expert_list)
    # Initialize Directed Evolution with the specified experts
    directed_evolution = evo_prot_grad.DirectedEvolution(
        #wt_fasta=temp_fasta_path,
        wt_protein=args.seed_seq,
        output=args.output_type,
        experts=expert_list,
        parallel_chains=args.parallel_chains,
        n_steps=args.n_steps,
        max_mutations=args.max_mutations,
        verbose=args.verbose                 
    )
    # print(dir(directed_evolution))
    # Run the evolution process
    variants, scores = directed_evolution()
    # Write results to file 
    directed_evolution.save_results(
        csv_filename=os.path.join(args.output_path, f"{args.seed_id}_de_results.csv"),
        variants=variants,
        scores=scores,
        n_seqs_to_keep=None, #keep all
        )

if __name__ == "__main__":
    args, _ = _parse_args()
    print(args)
    # Run directed evolution
    run_evo_prot_grad(args)
    print(f"DE results and params saved to {args.output_path}")
