#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow BoltzGen {
    take:
    input_dir
    config_file_name
    protocol_name

    main:

    input_dir = Channel.fromPath(input_dir)

    input_dir.view()

    BoltzGenTask(
        input_dir,
        config_file_name,
        protocol_name
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

    output:
    path 'output', emit: output, type: 'dir'

    script:
    """
    set -euxo pipefail
    
    # Use the cache directory baked into the container at /cache
    export HF_HOME=/cache
    
    mkdir output
    cp -r input_data/* .
    ls -la
    
    echo "Using built-in cache at /cache"
    ls -la /cache || echo "Warning: Cache directory not found"
    
    /usr/local/bin/boltzgen run ${config_file_name} \\
        --output output \\
        --protocol ${protocol_name} \\
        --cache /cache

    """
}

workflow {
    BoltzGen(
        params.input_dir,
        params.config_file_name,
        params.protocol_name
    )
}
