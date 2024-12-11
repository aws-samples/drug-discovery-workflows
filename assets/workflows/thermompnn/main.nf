#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow ThermoMPNN {
    take:
        pdb_path
        chain_id
        
    main:
    ThermoMPNNTask(
        pdb_path,
        chain_id,
    )

    ThermoMPNNTask.out.csv.set { csv }

    emit:
    csv
}

process ThermoMPNNTask {
    label 'thermompnn'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path pdb_path
        val chain_id

    output:
    path '*.csv', emit: csv

    script:
    """
    set -euxo pipefail
    pwd
    ls -la
    /opt/conda/bin/python /home/thermompnn/analysis/predict.py --pdb $pdb_path --chain $chain_id
        
    """
}

workflow {
    ThermoMPNN(
        Channel.fromPath(params.pdb_path),
        Channel.value(params.chain_id),
    )
}
