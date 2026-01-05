#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow TemStaPro {
    take:
        fasta_path
        window_size_predictions
        portion_size
        prot_t5_params
        
    main:
    TemStaProTask(
        fasta_path,
        window_size_predictions,
        portion_size,
        prot_t5_params
    )

    TemStaProTask.out.set { results }

    emit:
    results
}

process TemStaProTask {
    label 'temstapro'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path fasta_path
        val window_size_predictions
        val portion_size
        path prot_t5_params

    output:
    path 'output/*'

    script:
    """
    set -euxo pipefail
    mkdir output
    /usr/local/bin/python /home/TemStaPro/temstapro \
        --input-fasta $fasta_path \
        --PT-directory $prot_t5_params \
        --temstapro-directory '/home/TemStaPro' \
        --more-thresholds \
        --mean-output 'output/mean_output.tsv' \
        --per-res-output 'output/per_res_output.tsv' \
        --window-size-predictions $window_size_predictions \
        --per-residue-plot-dir output \
        --portion-size $portion_size
        
    """
}

workflow {
    TemStaPro(
        Channel.fromPath(params.fasta_path),
        params.window_size_predictions,
        params.portion_size,
        params.prot_t5_params
    )
}

