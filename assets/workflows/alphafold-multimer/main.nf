nextflow.enable.dsl = 2

params.fasta_path = "" 

// static data files are in nextflow.config

include {
    SearchUniref90;
    SearchMgnify;
    SearchBFD;
    SearchTemplatesTask;
    SearchUniprot;
    CombineSearchResults;
} from '../../modules/alphafold-multimer/searches'

include {
    UnpackBFD;
    UnpackPdb70nSeqres;
    UnpackMMCIF;
} from '../../modules/unpack'


workflow {
    CheckAndValidateInputsTask(params.target_id, params.fasta_path)

    // split fasta run parallel searches (Scatter)
    split_seqs = CheckAndValidateInputsTask.out.fasta
                 .splitFasta( file: true )
                 .map { filename -> tuple (filename.toString().split("/")[-1].split(".fasta")[0], filename) }

    uniref30 = Channel.fromPath(params.uniref30_database_src).first()
    alphafold_model_parameters = Channel.fromPath(params.alphafold_model_parameters).first()

    // Unpack the databases
    UnpackBFD(params.bfd_database_a3m_ffdata,
              params.bfd_database_a3m_ffindex,
              params.bfd_database_cs219_ffdata,
              params.bfd_database_cs219_ffindex,
              params.bfd_database_hhm_ffdata,
              params.bfd_database_hhm_ffindex)
    UnpackPdb70nSeqres(params.pdb70_src, params.pdb_seqres_src, params.db_pathname)
    UnpackMMCIF(params.pdb_mmcif_src1, 
                params.pdb_mmcif_src2, 
                params.pdb_mmcif_src3, 
                params.pdb_mmcif_src4, 
                params.pdb_mmcif_src5, 
                params.pdb_mmcif_src6, 
                params.pdb_mmcif_src7, 
                params.pdb_mmcif_src8, 
                params.pdb_mmcif_src9, 
                params.pdb_mmcif_obsolete)

    SearchUniref90(split_seqs, params.uniref90_database_src)
    SearchMgnify(split_seqs, params.mgnify_database_src)
    SearchUniprot(split_seqs, params.uniprot_database_src)
    SearchBFD(split_seqs, UnpackBFD.out.db_folder, params.uniref30_database_src)
    SearchTemplatesTask(SearchUniref90.out.msa_with_id, UnpackPdb70nSeqres.out.db_folder)

    // Gather
    CombineSearchResults(SearchUniref90.out.msa.collect(), SearchUniprot.out.msa.collect(), SearchMgnify.out.msa.collect(), SearchBFD.out.msa.collect(), SearchTemplatesTask.out.msa.collect())
    GenerateFeaturesTask(CheckAndValidateInputsTask.out.fasta, CombineSearchResults.out.msa_path, UnpackMMCIF.out.db_folder, UnpackMMCIF.out.db_obsolete)
    
    // Predict. Five separate models
    model_nums = Channel.of(0,1,2,3,4)
    AlphaFoldMultimerInference(params.target_id, GenerateFeaturesTask.out.features, params.alphafold_model_parameters, model_nums, params.random_seed, params.run_relax)

    MergeRankings(AlphaFoldMultimerInference.out.results.collect())
}

// Check the inputs and get size etc
process CheckAndValidateInputsTask {
    label 'protutils'
    cpus 2
    memory '4 GB'
    publishDir "/mnt/workflow/pubdir/inputs"

    input:
        val target_id
        path fasta_path

    output:
        stdout
        path "seq_info.json", emit: seq_info
        path "inputs.fasta", emit: fasta

    script:
    """
    set -euxo pipefail
    ls -alR
    /opt/venv/bin/python \
    /opt/venv/lib/python3.8/site-packages/putils/check_and_validate_inputs.py \
    --target_id=$target_id --fasta_path=$fasta_path
    """
}

// Generate features from the searches
process GenerateFeaturesTask {
    label 'data'
    cpus 4
    memory '16 GB'
    publishDir "/mnt/workflow/pubdir/features"

    input:
        path fasta_paths
        path msa_dir 
        path pdb_mmcif_folder
        path mmcif_obsolete_path

    output:
        path "output/features.pkl", emit: features
        path "output/generate_features_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output

    echo "***********************"
    ls -alR $msa_dir/
    echo "***********************"

    /opt/venv/bin/python /opt/generate_features.py \
      --fasta_paths=$fasta_paths \
      --msa_dir=$msa_dir \
      --template_mmcif_dir="$pdb_mmcif_folder" \
      --obsolete_pdbs_path="$mmcif_obsolete_path" \
      --template_hits="$msa_dir/pdb_hits.sto" \
      --model_preset=multimer \
      --output_dir=output \
      --max_template_date=2023-01-01  

    mv output/metrics.json output/generate_features_metrics.json
    """
}

// AlphaFold Multimer
process AlphaFoldMultimerInference {
    errorStrategy 'retry'
    label 'predict'
    cpus { 4 * Math.pow(2, task.attempt) }
    memory { 16.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries 2
    publishDir "/mnt/workflow/pubdir"
    input:
        val target_id
        path features
        path alphafold_model_parameters
        val modelnum
        val random_seed
        val run_relax

    output:
        path "output_model_${modelnum}/", emit: results
    
    script:
    """
    set -euxo pipefail
    mkdir -p model/params
    tar -xvf $alphafold_model_parameters -C model/params
    export XLA_PYTHON_CLIENT_MEM_FRACTION=4.0
    export TF_FORCE_UNIFIED_MEMORY=1
    /opt/conda/bin/python /app/alphafold/predict.py \
      --target_id=$target_id --features_path=$features --model_preset=multimer \
      --model_dir=model --random_seed=$random_seed --output_dir=output_model_${modelnum} \
      --run_relax=${run_relax} --use_gpu_relax=${run_relax} --model_num=$modelnum

    rm -rf output_model_${modelnum}/msas
    """
}


//Merge Rankings
process MergeRankings {
    cpus 2
    memory 4.GB
    publishDir "/mnt/workflow/pubdir"
    label 'data'

    input:
    path results

    output:
    path "rankings.json", emit: rankings
    path "top_hit*", emit: top_hit
    
    script:
    """
    mkdir -p output
    echo ${results}
    # Create top hit
    /opt/venv/bin/python /opt/merge_rankings.py --output_dir output/ --model_dirs ${results}
    mv output/top_hit* .
    mv output/rankings.json .
    """
}
