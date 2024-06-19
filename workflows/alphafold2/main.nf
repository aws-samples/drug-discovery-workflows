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
    UnpackRecords;
} from '../../modules/unpack'


workflow {
    fasta_records = Channel.fromPath(params.fasta_path).splitFasta(record: [id: true, header: true, seqString: true])

    UnpackRecords(fasta_records)

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

    SearchUniref90(UnpackRecords.out.fasta, params.uniref90_database_src)
    SearchMgnify(UnpackRecords.out.fasta, params.mgnify_database_src)
    SearchBFD(UnpackRecords.out.fasta, UnpackBFD.out.db_folder, params.uniref30_database_src)

    SearchTemplatesTask(UnpackRecords.out.fasta, SearchUniref90.out.msa, UnpackPdb70nSeqres.out.db_folder)

    GenerateFeaturesTask(UnpackRecords.out.fasta,
                         SearchUniref90.out.msa, 
                         SearchMgnify.out.msa, 
                         SearchBFD.out.msa, 
                         SearchTemplatesTask.out.pdb_hits, 
                         UnpackMMCIF.out.db_folder, 
                         UnpackMMCIF.out.db_obsolete)

    model_nums = Channel.of(0,1,2,3,4)
    AlphaFoldTask(UnpackRecords.out.fasta, GenerateFeaturesTask.out.features, params.alphafold_model_parameters, model_nums)
}


//GenerateFeaturesTask
process GenerateFeaturesTask {
    tag "${id}"
    label "data"
    cpus 2
    memory '8 GB'
    publishDir "/mnt/workflow/pubdir/${id}/features"

    input:
        tuple val(id), path(fasta_path)
        path uniref90_msa
        path mgnify_msa
        path bfd_msa
        path template_hits
        path pdb_mmcif_folder
        path mmcif_obsolete_path

    output:
        path "output/features.pkl", emit: features
        path "output/metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p \${TMPDIR}/msa
    cp -p $uniref90_msa \${TMPDIR}/msa/
    cp -p $mgnify_msa \${TMPDIR}/msa/
    cp -p $bfd_msa \${TMPDIR}/msa/
    cp -p $template_hits \${TMPDIR}/msa/

    /opt/venv/bin/python /opt/generate_features.py \
      --fasta_paths=$fasta_path \
      --msa_dir=\${TMPDIR}/msa \
      --template_mmcif_dir="$pdb_mmcif_folder" \
      --obsolete_pdbs_path="$mmcif_obsolete_path" \
      --template_hits=$template_hits \
      --model_preset=monomer_ptm \
      --output_dir=output \
      --max_template_date=2023-01-01       
    """
}

process AlphaFoldTask {
    tag "${id}_${modelnum}"
    errorStrategy 'retry'
    label 'predict'
    cpus { 4 * Math.pow(2, task.attempt) }
    memory { 16.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries 2
    publishDir "/mnt/workflow/pubdir/${id}/prediction_${modelnum}"
    input:
        tuple val(id), path(fasta_path)
        path features
        path alphafold_model_parameters
        val modelnum

    output:
        path "metrics.json", emit: metrics
        path "output/*", emit: results
    
    script:
    """
    set -euxo pipefail
    mkdir -p model/params
    tar -xvf $alphafold_model_parameters -C model/params
    /opt/conda/bin/python /app/alphafold/predict.py \
      --target_id=\${target_id} --features_path=$features --model_preset=monomer_ptm \
      --model_dir=model --random_seed=42 --output_dir=output \
      --run_relax=false --use_gpu_relax=false --model_num=$modelnum
    mv output/metrics.json .
    rm -rf output/msas
    """
}