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
} from './searches.nf'

include {
    UnpackBFD;
    UnpackPdb70nSeqres;
    UnpackMMCIF;
} from './unpack.nf'


workflow AlphaFold2Multimer {

    take:
    fasta_path
    alphafold_model_parameters
    bfd_database_a3m_ffdata
    bfd_database_a3m_ffindex
    bfd_database_cs219_ffdata
    bfd_database_cs219_ffindex
    bfd_database_hhm_ffdata
    bfd_database_hhm_ffindex
    pdb70_src
    pdb_seqres_src
    pdb_mmcif_src1
    pdb_mmcif_src2
    pdb_mmcif_src3
    pdb_mmcif_src4
    pdb_mmcif_src5
    pdb_mmcif_src6
    pdb_mmcif_src7
    pdb_mmcif_src8
    pdb_mmcif_src9
    pdb_mmcif_obsolete
    db_pathname
    uniref90_database_src
    uniprot_database_src
    mgnify_database_src
    uniref30_database_src
    random_seed
    run_relax

    main:

    // Convert to one or many files
    if (fasta_path[-1] == "/") {
        fasta_path = fasta_path + "*"
    } else {
        fasta_path = fasta_path
    }
    
    // [5nl6, 5nl6.fasta]
    // [5mlq, 5mlq.fasta]
    fasta_files = Channel
                  .fromPath(fasta_path)
                  .map { filename -> tuple ( filename.toString().split("/")[-1].split(".fa")[0], filename) }

    // 5nl6.fasta
    // 5mlq.fasta
    CheckAndValidateInputsTask(fasta_files)

    // Explode/scatter the fasta files into channel items per contained record ID
    // Write the exploded fasta records to their own file, include in tuple that contains original fasta file basename
    // [5nl6, 5nl6.1, 5nl6.1.fasta]
    // [5nl6, 5nl6.2, 5nl6.2.fasta]
    // [5mlq, 5mlq.1, 5mlq.1.fasta]
    // [5mlq, 5mlq.2, 5mlq.2.fasta]
    split_seqs = CheckAndValidateInputsTask.out.fasta.map { fastaFile ->
        def fastaBaseName = fastaFile.baseName
        def records = fastaFile.splitFasta( file: true )

        def fastaRecordTupleList = []
        records.forEach { record -> 
            fastaRecordTupleList.add(tuple (fastaBaseName, record.getBaseName(), record))
        }
        return fastaRecordTupleList
    } | flatMap

    alphafold_model_parameters = Channel.fromPath(alphafold_model_parameters).first()

    // Unpack the databases
    UnpackBFD(bfd_database_a3m_ffdata,
              bfd_database_a3m_ffindex,
              bfd_database_cs219_ffdata,
              bfd_database_cs219_ffindex,
              bfd_database_hhm_ffdata,
              bfd_database_hhm_ffindex)
    UnpackPdb70nSeqres(pdb70_src, pdb_seqres_src, db_pathname)
    UnpackMMCIF(pdb_mmcif_src1, 
                pdb_mmcif_src2, 
                pdb_mmcif_src3, 
                pdb_mmcif_src4, 
                pdb_mmcif_src5, 
                pdb_mmcif_src6, 
                pdb_mmcif_src7, 
                pdb_mmcif_src8, 
                pdb_mmcif_src9, 
                pdb_mmcif_obsolete)

    // Searches are call for each fastas * records
    SearchUniref90(split_seqs, uniref90_database_src)
    SearchMgnify(split_seqs, mgnify_database_src)
    SearchUniprot(split_seqs, uniprot_database_src)
    SearchBFD(split_seqs, UnpackBFD.out.db_folder, uniref30_database_src)

    SearchTemplatesTask(SearchUniref90.out.fasta_basename_with_record_id_and_msa, UnpackPdb70nSeqres.out.db_folder)

    // [5nl6, 5nl6.fasta, [output_5nl6.1/5nl6.1_uniref90_hits.sto, output_5nl6.2/5nl6.2_uniref90_hits.sto], [output_5nl6.2/5nl6.2_mgnify_hits.sto, output_5nl6.1/5nl6.1_mgnify_hits.sto], ...]
    // [5mlq, 5mlq.fasta, [output_5mlq.1/5mlq.1_uniref90_hits.sto, output_5mlq.2/5mlq.2_uniref90_hits.sto], [output_5mlq.1/5mlq.1_mgnify_hits.sto, output_5mlq.2/5mlq.2_mgnify_hits.sto], ...]
    // 
    // Combine/gather the search results into channels per original fasta file
    msa_tuples = fasta_files
                .join(SearchUniref90.out.fasta_basename_with_msa.groupTuple(), failOnMismatch: false, failOnDuplicate: false)
                .join(SearchMgnify.out.fasta_basename_with_msa.groupTuple(), failOnMismatch: false, failOnDuplicate: false)
                .join(SearchUniprot.out.fasta_basename_with_msa.groupTuple(), failOnMismatch: false, failOnDuplicate: false)
                .join(SearchBFD.out.fasta_basename_with_msa.groupTuple(), failOnMismatch: false, failOnDuplicate: false)
                .join(SearchTemplatesTask.out.fasta_basename_with_msa.groupTuple(), failOnMismatch: false, failOnDuplicate: false)

    // Per original fasta file, move all of the search result files (ArrayList of files) into single directory structure: msa/A, msa/B, ... 
    // Emit the first two elements of msa_tuples, and a single merged msa/ directory
    CombineSearchResults(msa_tuples)

    // Called per original fasta input file
    GenerateFeaturesTask(CombineSearchResults.out.fasta_basename_fasta_and_msa_path,
                        UnpackMMCIF.out.db_folder,
                        UnpackMMCIF.out.db_obsolete)
    
    // Predict. Five separate models
    model_nums = Channel.of(0,1,2,3,4)
    features = GenerateFeaturesTask.out.fasta_basename_with_features.combine(model_nums)
    inference_results = AlphaFoldMultimerInference(features, alphafold_model_parameters, random_seed, run_relax)

    merged_rankings = MergeRankings(inference_results.results.groupTuple(by: 0))

    inference = inference_results.results.collect()
    rankings = merged_rankings.rankings.collect()
    top_hit = merged_rankings.top_hit.collect()


    emit:
    inference
    rankings
    top_hit
}

// Check the inputs and get size etc
process CheckAndValidateInputsTask {
    tag "${fasta_basename}"
    label 'protutils'
    cpus 2
    memory '4 GB'
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/inputs"

    input:
        tuple val(fasta_basename), path(fasta_path)

    output:
        stdout
        path "seq_info.json", emit: seq_info
        path "${fasta_basename}.fasta", emit: fasta
        val "${fasta_basename}", emit: fasta_basename

    script:
    """
    set -euxo pipefail

    echo ">>>>>>>>>>>>>>>>>>>"
    echo $fasta_basename
    echo $fasta_path
    echo "<<<<<<<<<<<<<<<<<<<"

    ls -alR

    /opt/venv/bin/python \
    /opt/venv/lib/python3.8/site-packages/putils/check_and_validate_inputs.py \
    --target_id=$fasta_basename --fasta_path=$fasta_path --output_prefix=$fasta_basename

    ls -alR

    """
}

// Generate features from the searches
process GenerateFeaturesTask {
    tag "${fasta_basename}"
    label 'data'
    cpus 4
    memory '16 GB'
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/features"

    input:
        tuple val(fasta_basename), path(fasta_path), path(msa_dir)
        path pdb_mmcif_folder
        path mmcif_obsolete_path

    output:
        tuple val(fasta_basename), path("output/features.pkl"), emit: fasta_basename_with_features
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
      --fasta_paths=$fasta_path \
      --msa_dir=$msa_dir \
      --template_mmcif_dir="$pdb_mmcif_folder" \
      --obsolete_pdbs_path="$mmcif_obsolete_path" \
      --template_hits="$msa_dir/pdb_hits.sto" \
      --model_preset=multimer \
      --output_dir=output \
      --max_template_date=2023-01-01  

    echo "***********************"
    ls -alR output/
    echo "***********************"

    mv output/metrics.json output/generate_features_metrics.json
    """
}

// AlphaFold Multimer
process AlphaFoldMultimerInference {
    tag "${fasta_basename}_${modelnum}"
    errorStrategy 'retry'
    label 'predict'
    cpus { 4 * Math.pow(2, task.attempt) }
    memory { 16.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries 2
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/prediction_${modelnum}"
    input:
        tuple val(fasta_basename), path (features), val(modelnum)
        path alphafold_model_parameters
        val random_seed
        val run_relax

    output:
        tuple val(fasta_basename), path("output_model_${modelnum}/"), emit: results
    
    script:
    """
    set -euxo pipefail
    mkdir -p model/params
    tar -xvf $alphafold_model_parameters -C model/params
    export XLA_PYTHON_CLIENT_MEM_FRACTION=4.0
    export TF_FORCE_UNIFIED_MEMORY=1
    /opt/conda/bin/python /app/alphafold/predict.py \
      --target_id=$fasta_basename --features_path=$features --model_preset=multimer \
      --model_dir=model --random_seed=$random_seed --output_dir=output_model_${modelnum} \
      --run_relax=${run_relax} --use_gpu_relax=${run_relax} --model_num=$modelnum

    rm -rf output_model_${modelnum}/msas
    """
}


// Merge Rankings
process MergeRankings {
    tag "${id}"
    cpus 2
    memory 4.GB
    publishDir "/mnt/workflow/pubdir/${id}"
    label 'data'

    input:
    tuple val(id), path(results)

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

workflow  {
    AlphaFold2Multimer(
        params.fasta_path,
        params.alphafold_model_parameters,
        params.bfd_database_a3m_ffdata,
        params.bfd_database_a3m_ffindex,
        params.bfd_database_cs219_ffdata,
        params.bfd_database_cs219_ffindex,
        params.bfd_database_hhm_ffdata,
        params.bfd_database_hhm_ffindex,
        params.pdb70_src,
        params.pdb_seqres_src,
        params.pdb_mmcif_src1,
        params.pdb_mmcif_src2,
        params.pdb_mmcif_src3,
        params.pdb_mmcif_src4,
        params.pdb_mmcif_src5,
        params.pdb_mmcif_src6,
        params.pdb_mmcif_src7,
        params.pdb_mmcif_src8,
        params.pdb_mmcif_src9,
        params.pdb_mmcif_obsolete,
        params.db_pathname,
        params.uniref90_database_src,
        params.uniprot_database_src,
        params.mgnify_database_src,
        params.uniref30_database_src,
        params.random_seed,
        params.run_relax
    )
}
