#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow MMSeqs2 {
    take:
    fasta_path
    database_path

    main:
    MMSeqs2PrepareDatabaseTask(file(database_path))

    MMSeqs2SearchTask(
        file(fasta_path),
        MMSeqs2PrepareDatabaseTask.out
        )

    emit:
    MMSeqs2SearchTask.out
}

process MMSeqs2PrepareDatabaseTask {
    label 'mmseqs2'
    cpus 2
    memory '4 GB'
    maxRetries 1
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path database_path

    output:
    path "db", emit: db

    script:
    """
    set -euxo pipefail
    mkdir db
    /usr/local/bin/entrypoint createdb $database_path tmpDB
    /usr/local/bin/entrypoint makepaddedseqdb tmpDB db/gpuDB
    /usr/local/bin/entrypoint createindex db/gpuDB tmp --index-subset 2
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
    path database_path

    output:
    path "*.a3m", emit: msa

    script:
    """
    set -euxo pipefail
    /usr/local/bin/entrypoint createdb $fasta_path queryDB
    /usr/local/bin/entrypoint search queryDB $database_path/gpuDB result tmp --gpu 1
    /usr/local/bin/entrypoint result2msa queryDB $database_path/gpuDB result ${fasta_path.baseName}.a3m --msa-format-mode 5
    """
}

workflow {
    MMSeqs2(
        params.fasta_path,
        params.database_path
    )
}
