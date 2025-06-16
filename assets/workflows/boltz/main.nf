#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Boltz2 {
    take:
    input_path
    boltz_parameters

    main:

    input_channel = Channel.fromPath(input_path)
    boltz_parameters = Channel.fromPath(boltz_parameters)

    input_channel.view()

    Boltz2Task(
        input_channel,
        boltz_parameters
        )

    emit:
    Boltz2Task.out
}

process Boltz2Task {
    label 'boltz'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path input_path
    path boltz_parameters

    output:
    path "output/*", emit: output

    script:
    """
    set -euxo pipefail
    mkdir output

    # Extract CCD data
    /usr/bin/tar -xf $boltz_parameters/mols.tar -C $boltz_parameters

    /opt/venv/bin/boltz predict \
    --cache $boltz_parameters \
    --out_dir output \
    $input_path
      
    """
}

workflow {
    Boltz2(
        params.input_path,
        params.boltz_parameters
    )
}
