nextflow.enable.dsl = 2

include {
    SearchUniref90;
    SearchMgnify;
    SearchBFD;
    SearchTemplatesTask;
} from '../../modules/alphafold2/searches'

include {
    UnpackBFD;
    UnpackPdb70nSeqres;
    UnpackMMCIF;
} from '../../modules/unpack'

workflow {
    //Convert to files
    if (params.fasta_path[-1] == "/") {
        fasta_path = params.fasta_path + "*"
    } else {
        fasta_path = params.fasta_path
    }
    
    fasta_files = Channel
                  .fromPath(fasta_path)
                  .map { filename -> tuple ( filename.toString().split("/")[-1].split(".fasta")[0], filename) }

    uniref30 = Channel.fromPath(params.uniref30_database_src).first()
    alphafold_model_parameters = Channel.fromPath(params.alphafold_model_parameters).first()

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

    SearchUniref90(fasta_files, params.uniref90_database_src)
    SearchMgnify(fasta_files, params.mgnify_database_src)
    SearchBFD(fasta_files, UnpackBFD.out.db_folder, uniref30)

    SearchTemplatesTask(SearchUniref90.out.msa, UnpackPdb70nSeqres.out.db_folder)

    msa_tuples = fasta_files
                 .join(SearchUniref90.out.msa)
                 .join(SearchMgnify.out.msa)
                 .join(SearchBFD.out.msa)
                 .join(SearchTemplatesTask.out.pdb_hits)

    GenerateFeaturesTask(msa_tuples,
                         UnpackMMCIF.out.db_folder, 
                         UnpackMMCIF.out.db_obsolete)

    model_nums = Channel.of(0,1,2,3,4)
    features = GenerateFeaturesTask.out.features.combine(model_nums)
    AlphaFoldInference(features, alphafold_model_parameters, params.random_seed, params.run_relax)
}

process GenerateFeaturesTask {
    tag "${id}"
    label "data"
    cpus 2
    memory '8 GB'
    publishDir "/mnt/workflow/pubdir/${id}/features"

    input:
        tuple val(id), path(fasta_path), path(uniref90_msa), path(mgnify_msa), path(bfd_msa), path(template_hits)
        path pdb_mmcif_folder
        path mmcif_obsolete_path

    output:
        tuple val(id), path ("output/features.pkl"), emit: features
        path "output/metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    md5sum $uniref90_msa
    md5sum $mgnify_msa
    md5sum $bfd_msa

    mkdir -p msa
    cp -p $uniref90_msa msa/
    cp -p $mgnify_msa msa/
    cp -p $bfd_msa msa/
    cp -p $template_hits msa/

    /opt/venv/bin/python /opt/generate_features.py \
      --fasta_paths=$fasta_path \
      --msa_dir=msa \
      --template_mmcif_dir="$pdb_mmcif_folder" \
      --obsolete_pdbs_path="$mmcif_obsolete_path" \
      --template_hits=$template_hits \
      --model_preset=monomer_ptm \
      --output_dir=output \
      --max_template_date=2023-01-01       
    """
}

process AlphaFoldInference {
    tag "${id}_${modelnum}"
    errorStrategy 'retry'
    label 'predict'
    cpus { 2 * Math.pow(2, task.attempt) }
    memory { 8.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries 2
    publishDir "/mnt/workflow/pubdir/${id}/prediction_${modelnum}"

    input:
        tuple val(id), path (features), val(modelnum)
        path alphafold_model_parameters
        val random_seed
        val run_relax

    output:
        path "metrics.json", emit: metrics
        path "output/*", emit: results
    
    script:
    """
    set -euxo pipefail
    mkdir -p model/params
    tar -xvf $alphafold_model_parameters -C model/params
    export XLA_PYTHON_CLIENT_MEM_FRACTION=4.0
    export TF_FORCE_UNIFIED_MEMORY=1
    /opt/conda/bin/python /app/alphafold/predict.py \
      --target_id=$id --features_path=$features --model_preset=monomer_ptm \
      --model_dir=model --random_seed=$random_seed --output_dir=output \
      --run_relax=${run_relax} --use_gpu_relax=${run_relax} --model_num=$modelnum
    mv output/metrics.json .
    rm -rf output/msas
    """
}