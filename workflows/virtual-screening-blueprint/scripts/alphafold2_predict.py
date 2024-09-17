import dataclasses
import tempfile
from typing import Any, Dict
import uuid
import logging as pylogging
logger = pylogging.getLogger()
import os
import sys
from types import SimpleNamespace

from fastapi import HTTPException
from starlette.status import HTTP_400_BAD_REQUEST

from nimlib.nim_inference_api_builder.http_api import HttpNIMApiInterface as NIMInterface
from nimlib.standard_files import License, NIMVersion

from data_models import (
    AlphaFold2MSAToStructInputs,
    AlphaFold2SeqToMSAInputs,
    AlphaFold2SeqToStructInputs,
    AlphaFold2MultimerSeqsToStructInputs,
    AlphaFold2MultimerSeqsToMSAInputs,
    AlphaFold2MultimerMSAToStructInputs,
    HTTPValidationError,
)

from alphafold2_inference_wrappers import *
from mmseqs2_wrapper import MMSeqs2Manager
from foldnim_wrappers import *

## TODO: refactor to get this out of here
from alphafold.data.tools import hhsearch, hmmsearch
from alphafold.data import pipeline, templates
from alphafold.common import protein

NIM_CACHE_PATH="/mnt/workflow"

def check_file_exists(filepath, fail_on_missing=True, silent=True):
    if not os.path.isfile(filepath):
        print(f"File not found: {filepath}")
        if fail_on_missing:
            raise FileNotFoundError(f"The file '{filepath}' does not exist.")
        return False
    else:
        if not silent:
            print(f"File exists: {filepath}")
        return True

def verify_alphafold2_data(data_dir, return_early_if_missing: bool = False):
    """
    Checks the NIM cache for the following files,
    in a directory specified by the model_manifest.yaml,
    which for example looks like: 'alphafold2-data_v0.0.1'
    
    This function runs at NIM startup.
    
    The point of this function is to fail FAST if the user does not have the necessary data.
    """
    
    af2_data = {
        'mgnify': ['mgy_clusters_2022_05.fa'],
        'params': [
            'LICENSE',
            'params_model_1_multimer_v3.npz',
            'params_model_1.npz',
            'params_model_1_ptm.npz',
            'params_model_2_multimer_v3.npz',
            'params_model_2.npz',
            'params_model_2_ptm.npz',
            'params_model_3_multimer_v3.npz',
            'params_model_3.npz',
            'params_model_3_ptm.npz',
            'params_model_4_multimer_v3.npz',
            'params_model_4.npz',
            'params_model_4_ptm.npz',
            'params_model_5_multimer_v3.npz',
            'params_model_5.npz',
            'params_model_5_ptm.npz'
        ],
        'pdb70': [
            'md5sum',
            'pdb70_a3m.ffdata',
            'pdb70_a3m.ffindex',
            'pdb70_clu.tsv',
            'pdb70_cs219.ffdata',
            'pdb70_cs219.ffindex',
            'pdb70_hhm.ffdata',
            'pdb70_hhm.ffindex',
            'pdb_filter.dat'
        ],
        'pdb_mmcif': ['obsolete.dat', 'pdb_mmcif.hdf5'],
        'pdb_seqres': ['pdb_seqres.txt'],
        'small_bfd': ['bfd-first_non_consensus_sequences.fasta'],
        # 'test': ['test.fasta'],
        # 'uniprot': ['uniprot.fasta'],
        # 'uniref30': [
        #     'UniRef30_2021_03_a3m.ffdata',
        #     'UniRef30_2021_03_a3m.ffindex',
        #     'UniRef30_2021_03_cs219.ffdata',
        #     'UniRef30_2021_03_cs219.ffindex',
        #     'UniRef30_2021_03_hhm.ffdata',
        #     'UniRef30_2021_03_hhm.ffindex',
        #     'UniRef30_2021_03.md5sums'
        # ],
        'uniref90': ['uniref90.fasta']
    }

    nim_cache_path = os.environ.get("NIM_CACHE_PATH", NIM_CACHE_DEFAULT)
    nim_model_name = os.environ.get("NIM_MODEL_NAME", "alphafold2-data")
    nim_model_version = os.environ.get("NIM_MODEL_VERSION", "1.0.0")
    for key in af2_data:
        ## check the NIM Cache for each directory and file within directory.
        ## TODO
        for data_file in af2_data[key]:
            ## TODO: change the model name.
            found = check_file_exists(os.path.join(nim_cache_path,
                                           f"{nim_model_name}_v{nim_model_version}",
                                           key, data_file),
                              fail_on_missing=False)
            if return_early_if_missing and not found:
                return False
    return True


def nim_api_post_call_protein_structure_alphafold2_predict_structure_from_sequence_post(
    body: AlphaFold2SeqToStructInputs
) -> Any:
    logger.info(
        "nim_api_post_call_protein_structure_alphafold2_predict_structure_from_sequence_post called"
    )
    """
    Provide your implementation for this "End-to-end protein sequence to structure prediction using AlphaFold2." API
    """
    msa_request_body = AlphaFold2SeqToMSAInputs(
        sequence=body.sequence,
        algorithm=body.algorithm,
        bit_score=body.bit_score,
        e_value=body.e_value,
        databases=body.databases,
        iterations=body.iterations,
        max_msa_sequences=body.max_msa_sequences
    )
    
    alignments_and_templates = nim_api_post_call_protein_structure_alphafold2_predict_msa_from_sequence_post(msa_request_body)
    templates = [dataclasses.asdict(x) for x in alignments_and_templates["templates"]]
    struct_query: AlphaFold2MSAToStructInputs = AlphaFold2MSAToStructInputs(
        alignments=alignments_and_templates["alignments"],
        templates=templates,
        sequence=body.sequence,
        relax_prediction=body.relax_prediction
    )
    
    structs = nim_api_post_call_protein_structure_alphafold2_predict_structure_from_msa_post(struct_query)
    
    return structs


def nim_api_post_call_protein_structure_alphafold2_predict_msa_from_sequence_post(
    body: AlphaFold2SeqToMSAInputs
) -> Any:
    logger.info(
        "nim_api_post_call_protein_structure_alphafold2_predict_msa_from_sequence_post called"
    )
    """
    Provide your implementation for this "Produce a Multiple Sequence Alignment for a query sequence against a set of databases." API
    """
    ## TODO: get user-defined database locations from ENV.
    msa_database_configs = create_msa_database_configs("NIM_CACHE_PATH")
    ## verify presence of all data files.
    
    dbs_to_ship = tuple([msa_database_configs[name] for name in body.databases])
    dbname_to_alignments = create_alignments(body.sequence,
                                databases=dbs_to_ship,
                                e_value=body.e_value,
                                bit_score=body.bit_score,
                                iterations=body.iterations,
                                algorithm=body.algorithm,
                                n_cpus_per_aln=os.environ.get("NIM_PARALLEL_THREADS_PER_MSA", 8), ## TODO: implement at API level
                                n_workers=os.environ.get("NIM_PARALLEL_MSA_RUNNERS", 3), ## TODO: programatically set this.
                                max_sto_sequences=body.max_msa_sequences) ## TODO: add to API, implement in accel jackhmmer
    
    ## Use the first MSA in the output.
    msa_for_templates = dbname_to_alignments[next(iter(dbname_to_alignments))].output
    ## IF uniref90 is in the database alignment, use that, rather than just the first MSA.
    if "uniref90" in dbname_to_alignments:
        msa_for_templates = dbname_to_alignments["uniref90"].output
   
    ## TODO: refactor this. We should have no alphafold code in this module; only wrapper code.
    structural_database_configs = create_structural_database_configs("NIM_CACHE_PATH")
    
    template_searcher = None
    if body.template_searcher == "hhsearch":        
        template_searcher = hhsearch.HHSearch(
                binary_path=Constants.hhsearch_binary_path,
                databases=[structural_database_configs["pdb70"]["path"]],
                n_cpus=8) ## TODO: dynamically determine n cpu on host
    else:
        template_searcher = hmmsearch.Hmmsearch(binary_path=Constants.hmmsearch_binary_path,
                                                hmmbuild_binary_path=Constants.hmmbuild,
                                                database_path=structural_database_configs["pdb_seqres"]["path"])
    ## Takes: the sequence,
    ## a STO or A3M file as a long string
    ## A template searcher
    msa_templates = create_templates(body.sequence,
                                    msa_for_templates,
                                    template_searcher=template_searcher)

    alignments = dbname_to_alignments
    
    return {
        "alignments" : alignments,
        "templates" : msa_templates
    }


def nim_api_post_call_protein_structure_alphafold2_predict_structure_from_msa_post(
    body: AlphaFold2MSAToStructInputs
) -> Any:
    logger.info(
        "nim_api_post_call_protein_structure_alphafold2_predict_structure_from_msa_post called"
    )
    """
    Provide your implementation for this "Predict a protein structure given a Multiple Sequence Alignment and templates for a query sequence against a set of databases." API
    """
    if not any_gpu_attached():
        logger.error("No GPU attached; predict-structure-from-msa endpoint may not be called.")
    
    ## TODO:
    ## get NIM Cache path
    ## verify presence of all data files.
    # # TODO extract method
    target_fasta = os.path.join(tempfile.gettempdir(), f'{uuid.uuid1()}.fasta')
    with open(target_fasta, 'wt') as f:
        f.write(f'>query\n{body.sequence}')
    
    all_predicted_pdbs = []
        
    run_multimer_system = False
    ## TODO: Add to API
    model_preset = body.structure_model_preset
    ## TODO: return error if model preset not in set of supported models
    ## TODO: add to API
    # num_predictions_per_model = Constants.num_multimer_predictions_per_model if run_multimer_system else 1
    num_predictions_per_model = body.num_predictions_per_model
    if model_preset == ModelPreset.MONOMER_CASP14:
        num_ensemble = 8
    else:
        num_ensemble = 1
        
    ## TODO: refactor. No AlphaFold2 code should be in this repo.
    sequence_features = pipeline.make_sequence_features(
        sequence=body.sequence,
        description=f"{hash(body.sequence)}",
        num_res=len(body.sequence))
    logger.info("Created sequence features.")
    
    ## Create MSA features:
    msa_features = create_msa_features(body.alignments)
    logger.info("Created MSA features.")

    
    ## Create template features
    structural_database_configs = create_structural_database_configs("NIM_CACHE_PATH")
    ## TODO: refactor
    template_featurizer = templates.HhsearchHitFeaturizer(
            mmcif_dir=structural_database_configs["template_mmcif_dir"]["path"],
            max_template_date=Constants.max_template_date,
            max_hits=Constants.max_template_hits,
            kalign_binary_path=Constants.kalign_binary_path,
            release_dates_path=None,
            obsolete_pdbs_path=structural_database_configs["obsolete_pdbs"]["path"])
    ## TODO: abstract into method.
    template_hits = [template_hit_decoder(x) for x in body.templates]
    template_features = create_template_features(body.sequence, template_hits, template_featurizer)
    logger.info("Created template features.")
    features = {**sequence_features, **msa_features, **template_features.features}

    ## TODO: add an assert that fails if no params present.
    model_runners = initialize_model_runners(
        model_preset=model_preset,
        data_dir=model_data_path("NIM_CACHE_PATH"),
        num_ensemble=num_ensemble,
        run_multimer_system=run_multimer_system, 
        num_predictions_per_model=num_predictions_per_model
    )
    logger.info("Beginning structural prediction module.")
    unrelaxed_proteins, ranked_order = predict_structure(model_runners,
                                                            features,
                                                            target_fasta,
                                                            random_seed=Constants.random_seed)

    logger.info("Completed structural prediction.")
    predicted_pdbs = {}
    
    
    #structs = self.nim_api_post_call_protein_structure_alphafold2_predict_structure_from_msa_post(struct_query)
    #   File "/opt/inference.py", line 282, in nim_api_post_call_protein_structure_alphafold2_predict_structure_from_msa_post
    #     for key, protein in unrelaxed_proteins:
    # ValueError: too many values to unpack (expected 2)

    if body.relax_prediction:
        logger.info("Running structure relaxation.")
        predicted_pdbs, relax_metrics = relax_structures(unrelaxed_proteins,
                                            ranked_order,
                                            models_to_relax=body.structure_models_to_relax,
                                            use_gpu=Constants.use_gpu_relax,
                                        )
        logger.info("Completed relaxation.")
    else:
        logger.info(f"{type(unrelaxed_proteins)}")
        logger.info(f"{unrelaxed_proteins.keys()}")
        for key in unrelaxed_proteins:
            predicted_pdbs[key] = protein.to_pdb(unrelaxed_proteins[key])
        # for key, protein in unrelaxed_proteins:
        #     predicted_pdbs[key] = protein.to_pdb(protein)

    # # Combine results
    # prediction_result['relaxed_structure'] = relaxed_structure

    for model_name in ranked_order:
        if model_name in predicted_pdbs:
            all_predicted_pdbs.append(predicted_pdbs[model_name])
    return all_predicted_pdbs


def setup_mmseqs():
    mm_manager = MMSeqs2Manager()
    if mm_manager.mmseqs_approved():
        logger.info("Agreement to MMSeqs2 license found;")
        logger.info("Installing MMSeqs2...")
        mm_manager.setup_mmseqs2()
        ## TODO: optionally start db server if GPU set, returning handle to kill / join
        ## TODO: optionally start search server if GPU set, returning handle to kill / join
    
        logger.info("MMSeqs2 has been successfully installed.")
        logger.info("Creating MMSeqs2 databases...")
        mm_manager.prepare_msa_databases_for_mmseqs2(NIM_CACHE_DEFAULT)
        logger.info("MMSeqs2 databases were successfully created.")

if __name__ == "__main__":
    NIM_CACHE_DEFAULT="/mnt/workflow/nim/alphafold2"
    nim_cache_path = os.environ.get("NIM_CACHE_PATH", NIM_CACHE_DEFAULT)
    ## Verify presence of data required to serve model.
    all_files_present = verify_alphafold2_data(nim_cache_path)
    if not all_files_present:
        raise FileNotFoundError("Supporting data files, including parameters, MSA databases, and pdb databases not found.")
    setup_mmseqs()
    # inputdata=json.loads(open("input.json"), object_hook=lambda d: SimpleNamespace(**d))
    proteinId, proteinSeq = sys.argv[1].split('zzzz')
    body = AlphaFold2SeqToStructInputs(
    	sequence = proteinSeq
    )
    structs = nim_api_post_call_protein_structure_alphafold2_predict_structure_from_sequence_post(body)
    for i, p in enumerate(structs):
        with open(f'{proteinId}_{i}.pdb', 'w') as fh:
            fh.write(p)
