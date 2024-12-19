#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow MMSeqs2 {
    take:
    fasta_path
    database_name

    main:
    MMSeqs2DatabasePrepTask(
        database_name
        )

    MMSeqs2SearchTask(
        fasta_path,
        MMSeqs2DatabasePrepTask.out
        )

    emit:
    MMSeqs2SearchTask.out
}

process MMSeqs2DatabasePrepTask {
    label 'mmseqs2'
    cpus 4
    memory '16 GB'
    maxRetries 1
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    val database_name

    output:
    path "$database_name", emit: msa

    script:
    """
    set -euxo pipefail
    mkdir -p tmp $database_name
    /usr/local/bin/entrypoint databases $database_name cpu tmp
    /usr/local/bin/entrypoint makepaddedseqdb cpu $database_name/targetDB
    """
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
    path db

    output:
    path "msa.a3m", emit: msa

    script:
    """
    set -euxo pipefail

    /usr/local/bin/entrypoint createdb $fasta_path queryDB
    /usr/local/bin/entrypoint search queryDB $db/targetDB result tmp --gpu 1
    /usr/local/bin/entrypoint result2msa queryDB $db/targetDB result msa.a3m --msa-format-mode 5
    """
}

workflow {
    MMSeqs2(
        params.fasta_path,
        params.database_name
    )
}
