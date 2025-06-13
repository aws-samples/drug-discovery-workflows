#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Boltz2 {
    take:
    input_path
    boltz2_parameters

    main:

    input_channel = Channel.fromPath(input_path)
    boltz2_parameters = Channel.fromPath(boltz2_parameters)

    input_channel.view()

    Boltz2Task(
        input_channel,
        boltz2_parameters
        )

    emit:
    Boltz2Task.out
}

process Boltz2Task {
    label 'boltz2'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path input_path
    path boltz2_parameters

    output:
    path "output/*", emit: output

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/venv/bin/boltz predict \
    --cache $boltz2_parameters \
    --out_dir output \
    $input_path
      
    """
}

workflow {
    Boltz2(
        params.input_path,
        params.boltz2_parameters
    )
}
