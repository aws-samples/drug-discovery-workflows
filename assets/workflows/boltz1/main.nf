#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Boltz1 {
    take:
    yaml_path
    boltz1_parameters

    main:

    input_channel = Channel.fromPath(yaml_path)
    boltz1_parameters = Channel.fromPath(boltz1_parameters)

    input_channel.view()

    Boltz1Task(
        input_channel,
        boltz1_parameters
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
    path boltz1_parameters

    output:
    path "output/*", emit: output

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/conda/bin/boltz \
    --cache $boltz1_parameters \
    --out_dir output \
    $yaml_path
      
    """
}

workflow {
    Boltz1(
        params.yaml_path,
        params.boltz1_parameters
    )
}
