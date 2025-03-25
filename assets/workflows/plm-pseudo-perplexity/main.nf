#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow PLMPPL {
    take:
    fasta_path
    model_parameters
    model_type

    main:
    PPLTask(fasta_path, model_parameters, model_type)
    PPLTask.out.ppl_results.set { ppl_results }

    emit:
    ppl_results
}

process PPLTask {
    label 'ppl'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path fasta_path
    path model_parameters
    val model_type

    output:
    path "*.jsonl", emit: ppl_results

    script:
    """
    set -euxo pipefail
    /opt/conda/bin/python /home/scripts/calculate_ppl.py $fasta_path \
        --output_dir "." \
        --pretrained_model_name_or_path $model_parameters \
        --model_type $model_type
    mv ppl.jsonl ppl_${task.index}.jsonl
    """
}

workflow {
    PLMPPL(
        Channel.fromPath(params.fasta_path),
        Channel.value(params.model_parameters),
        Channel.value(params.model_type)
    )
}
