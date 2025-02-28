#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Chai1 {
    take:
        fasta_file
        msa_directory
        template_hits_path
        pdb_divided_path
        pdb_obsolete_path
        model_parameters
        recycle_msa_subsample
        num_trunk_recycles
        num_diffn_timesteps
        num_diffn_samples
        num_trunk_samples
        seed

    main:

    pdb_divided_channel = Channel.fromPath(pdb_divided_path)
    pdb_obsolete_channel = Channel.fromPath(pdb_obsolete_path)
    pdb_snapshot_channel = pdb_divided_channel.concat(pdb_obsolete_channel).collect()

    Chai1Task(
        fasta_file,
        msa_directory,
        template_hits_path,
        pdb_snapshot_channel,
        model_parameters,
        recycle_msa_subsample,
        num_trunk_recycles,
        num_diffn_timesteps,
        num_diffn_samples,
        num_trunk_samples,
        seed
    )

    emit:
    Chai1Task.out
}

process Chai1Task {
    label 'chai1'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path fasta_file
        path msa_directory
        path template_hits
        path pdb, stageAs: 'pdb/*'
        path model_parameters
        val recycle_msa_subsample
        val num_trunk_recycles
        val num_diffn_timesteps
        val num_diffn_samples
        val num_trunk_samples
        val seed

    output:
    path 'output/*'

    script:
    """
    set -euxo pipefail
    mkdir output


    export CHAI_DOWNLOADS_DIR=${model_parameters}
    export PDB_TEMPLATE_DIR=pdb
    chai-lab fold \
    --msa-directory ${msa_directory} \
    --template-hits-path ${template_hits} \
    ${fasta_file} output
        
    """
}

workflow {
    Chai1(
        params.fasta_file,
        params.msa_directory,
        params.template_hits_path,
        params.pdb_divided_path,
        params.pdb_obsolete_path,
        params.model_parameters,
        params.recycle_msa_subsample,
        params.num_trunk_recycles,
        params.num_diffn_timesteps,
        params.num_diffn_samples,
        params.num_trunk_samples,
        params.seed
    )
}
