#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow MMSeqs2 {
    take:
    fasta_path
    database_path

    main:

    MMSeqs2SearchTask(
        fasta_path,
        database_path
        )

    emit:
    MMSeqs2SearchTask.out
}

process MMSeqs2SearchTask {
    label 'mmseqs2'
    cpus 8
    memory '32 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path fasta_path
    path database_path

    output:
    path "msa.a3m", emit: msa

    script:
    """
    set -euxo pipefail

    /usr/local/bin/entrypoint createdb $fasta_path queryDB
    /usr/local/bin/entrypoint search queryDB $database_path result tmp --gpu 1
    /usr/local/bin/entrypoint result2msa queryDB $database_path result msa.a3m --msa-format-mode 5
    """
}

workflow {
    MMSeqs2(
        params.fasta_path,
        params.database_path
    )
}
