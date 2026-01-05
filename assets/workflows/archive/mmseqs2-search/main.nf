#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow MMSeqs2 {
    take:
    fasta_path
    database_path

    main:

    db_channel = Channel.fromPath(database_path)
    db_channel.view()
    MMSeqs2PrepareDatabaseTask(db_channel)

    // Convert to one or many files
    if (params.fasta_path[-1] == "/") {
        fasta_path = params.fasta_path + "*"
    } else {
        fasta_path = params.fasta_path
    }

    fasta_channel = Channel.fromPath(fasta_path)
    fasta_channel.view()
    search_input = fasta_channel.combine(MMSeqs2PrepareDatabaseTask.out)
    search_input.view()
    MMSeqs2SearchTask(
        search_input
        )

    emit:
    MMSeqs2SearchTask.out
}

process MMSeqs2PrepareDatabaseTask {
    label 'mmseqs2'
    cpus 16
    memory '32 GB'
    maxRetries 1

    input:
    path database_path

    output:
    path "db", emit: db

    script:
    """
    set -euxo pipefail
    mkdir db
    mmseqs createdb $database_path tmpDB
    mmseqs makepaddedseqdb tmpDB db/gpuDB
    mmseqs createindex db/gpuDB tmp --index-subset 2
    """
}

process MMSeqs2SearchTask {
    label 'mmseqs2'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    tuple path(fasta_path), path(database_path)

    output:
    path "*.a3m", emit: msa

    script:
    """
    set -euxo pipefail
    mmseqs createdb $fasta_path queryDB
    mmseqs search queryDB $database_path/gpuDB result tmp --gpu 1
    mmseqs result2msa queryDB $database_path/gpuDB result ${fasta_path.baseName}.a3m --msa-format-mode 5
    """
}

workflow {
    MMSeqs2(
        params.fasta_path,
        params.database_path
    )
}
