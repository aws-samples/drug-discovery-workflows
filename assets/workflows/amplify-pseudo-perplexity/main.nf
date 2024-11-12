#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow AMPLIFY {
    take:
    fasta_path
    model_parameters

    main:
    PPLTask(fasta_path, model_parameters)
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

    output:
    path 'ppl.jsonl', emit: ppl_results

    script:
    """
    set -euxo pipefail
    /opt/conda/bin/python /home/scripts/calculate_ppl.py $fasta_path \
        --output_dir "." \
        --pretrained_model_name_or_path $model_parameters
    """
}

workflow {
    AMPLIFY(
        Channel.fromPath(params.fasta_path),
        Channel.fromPath(params.model_parameters)
    )
}
