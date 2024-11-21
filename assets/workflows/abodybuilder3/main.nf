#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow ABodyBuilder3 {
    take:
    fasta_path
    model_parameters

    main:
    ABodyBuilder3Task(fasta_path, model_parameters)
    ABodyBuilder3Task.out.pdb.set { pdb }

    emit:
    pdb
}

process ABodyBuilder3Task {
    label 'abodybuilder3'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path fasta_path
    path model_parameters

    output:
    path '*.pdb', emit: pdb

    script:
    """
    set -euxo pipefail
    which tar
    tar -xzvf $model_parameters
    /opt/conda/bin/python /home/scripts/abb3_inference.py $fasta_path \
        --model_path plddt-loss/best_second_stage.ckpt
    """
}

workflow {
    ABodyBuilder3(
        Channel.fromPath(params.fasta_path),
        Channel.fromPath(params.model_parameters)
    )
}
