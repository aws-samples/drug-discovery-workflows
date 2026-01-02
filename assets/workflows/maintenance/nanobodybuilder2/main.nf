#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow NanoBodyBuilder2 {
    take:
    fasta_path
    model_parameters_1
    model_parameters_2
    model_parameters_3
    model_parameters_4

    main:
    NanoBodyBuilder2Task(
        fasta_path, 
        model_parameters_1, 
        model_parameters_2, 
        model_parameters_3, 
        model_parameters_4
        )
    NanoBodyBuilder2Task.out.pdb.set { pdb }
    NanoBodyBuilder2Task.out.nanobodybuilder2_metrics.set { nanobodybuilder2_metrics }

    emit:
    pdb
    nanobodybuilder2_metrics
}

process NanoBodyBuilder2Task {
    label 'abodybuilder3'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    each fasta_path
    path model_parameters_1
    path model_parameters_2
    path model_parameters_3
    path model_parameters_4

    output:
    path 'output/*.pdb', emit: pdb
    path 'output/*.jsonl', emit: nanobodybuilder2_metrics

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/conda/bin/python /home/scripts/nbb2_inference.py $fasta_path
    cat output/*.json >> output/nanobodybuilder2_metrics_${task.index}.jsonl

    """
}

workflow {
    NanoBodyBuilder2Task(
        Channel.fromPath(params.fasta_path),
        Channel.fromPath(params.model_parameters_1),
        Channel.fromPath(params.model_parameters_2),
        Channel.fromPath(params.model_parameters_3),
        Channel.fromPath(params.model_parameters_4)
    )
}
