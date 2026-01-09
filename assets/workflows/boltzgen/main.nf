#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow BoltzGen {
    take:
    input_dir
    config_file_name
    protocol_name
    boltzgen_parameters

    main:

    input_dir = Channel.fromPath(input_dir)
    boltzgen_parameters = Channel.fromPath(boltzgen_parameters)

    input_dir.view()

    BoltzGenTask(
        input_dir,
        config_file_name,
        protocol_name,
        boltzgen_parameters
        )

    emit:
    BoltzGenTask.out
}

process BoltzGenTask {
    label 'boltzgen'
    cpus 4
    memory '16 GB'
    time '4h'
    accelerator 1, type: 'nvidia-l4-a10g'
    publishDir '/mnt/workflow/pubdir/boltz_predictions', mode: 'copy', saveAs: { filename -> filename }

    input:
    path input_dir, stageAs: 'input_data'
    val config_file_name
    val protocol_name
    path boltzgen_parameters, stageAs: 'boltz_cache'

    output:
    path 'output', emit: output, type: 'dir'

    script:
    """
    set -euxo pipefail
    mkdir output
    cp -r input_data/* .
    ls -la
    /usr/local/bin/boltzgen run ${config_file_name} \\
        --output output \\
        --protocol ${protocol_name}

    """
}

workflow {
    BoltzGen(
        params.input_dir,
        params.config_file_name,
        params.protocol_name,
        params.boltzgen_parameters
    )
}
