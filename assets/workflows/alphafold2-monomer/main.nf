nextflow.enable.dsl = 2

include {
    SearchUniref90
    SearchMgnify
    SearchBFD
    SearchTemplatesTask
} from './searches'

include {
    UnpackBFD
    UnpackPdb70nSeqres
    UnpackMMCIF
} from './unpack'

workflow AlphaFold2Monomer {

    take:
        fasta_path
        uniref30_database_src
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
        mgnify_database_src
        random_seed
        run_relax

    main:

    //Convert to files
    if (fasta_path[-1] == '/') {
        fasta_path = fasta_path + '*'
    } else {
        fasta_path = fasta_path
    }

    fasta_files = Channel
                  .fromPath(fasta_path)
                  .map { filename -> tuple(filename.toString().split('/')[-1].split('.fasta')[0], filename) }

    uniref30 = Channel.fromPath(uniref30_database_src).first()
    alphafold_model_parameters = Channel.fromPath(alphafold_model_parameters).first()

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

    SearchUniref90(fasta_files, uniref90_database_src)
    SearchMgnify(fasta_files, mgnify_database_src)
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

    model_nums = Channel.of(0, 1, 2, 3, 4)
    features = GenerateFeaturesTask.out.features.combine(model_nums)
    AlphaFoldInference(features, alphafold_model_parameters, random_seed, run_relax)

    merged = MergeRankings(AlphaFoldInference.out.results.groupTuple(by: 0))

   emit:
   merged
}

process GenerateFeaturesTask {
    tag "${id}"
    label 'data'
    cpus 2
    memory '8 GB'
    publishDir "/mnt/workflow/pubdir/${id}/features"

    input:
        tuple val(id), path(fasta_path), path(uniref90_msa), path(mgnify_msa), path(bfd_msa), path(template_hits)
        path pdb_mmcif_folder
        path mmcif_obsolete_path

    output:
        tuple val(id), path('output/features.pkl'), emit: features
        path 'output/metrics.json', emit: metrics

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
    publishDir "/mnt/workflow/pubdir/${id}"

    input:
        tuple val(id), path(features), val(modelnum)
        path alphafold_model_parameters
        val random_seed
        val run_relax

    output:
        tuple val(id), path("output_model_${modelnum}/"), emit: results

    script:
    """
    set -euxo pipefail
    mkdir -p model/params
    tar -xvf $alphafold_model_parameters -C model/params
    export XLA_PYTHON_CLIENT_MEM_FRACTION=4.0
    export TF_FORCE_UNIFIED_MEMORY=1
    /opt/conda/bin/python /app/alphafold/predict.py \
      --target_id=$id --features_path=$features --model_preset=monomer_ptm \
      --model_dir=model --random_seed=$random_seed --output_dir=output_model_${modelnum} \
      --run_relax=${run_relax} --use_gpu_relax=${run_relax} --model_num=$modelnum

    rm -rf output_model_${modelnum}/msas
    """
}

//Merge Rankings
process MergeRankings {
    tag "${id}"
    cpus 2
    memory 4.GB
    publishDir "/mnt/workflow/pubdir/${id}"
    label 'data'

    input:
    tuple val(id), path(results)

    output:
    path 'rankings.json', emit: rankings
    path 'top_hit*', emit: top_hit

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

workflow {
    AlphaFold2Monomer(
        params.fasta_path,
        params.uniref30_database_src,
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
        params.mgnify_database_src,
        params.random_seed,
        params.run_relax
    )
}
