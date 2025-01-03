#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Boltz1 {
    take:
    yaml_path

    main:

    input_channel = Channel.fromPath(yaml_path)
    input_channel.view()

    Boltz1Task(
        input_channel
        )

    emit:
    Boltz1Task.out
}

process Boltz1Task {
    label 'boltz1'
    cpus 8
    memory '16 GB'
    maxRetries 1

    input:
    path yaml_path

    output:
    path "output/*", emit: output

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/conda/bin/boltz $yaml_path
    """
}

workflow {
    Boltz1(
        params.yaml_path,
    )
}
