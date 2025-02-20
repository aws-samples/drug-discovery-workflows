#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow ColabfoldSearch {
    take:
        query
        uniref30_db_path
        envdb_db_path
        filter
        expand_eval
        align_eval
        diff
        qsc
        max_accept
        pairing_strategy
        db_load_mode
        unpack
        gpu_server

    main:

    query_channel = Channel.fromPath(query)
    query_channel.view()

    if (params.uniref30_db_path[-1] == "/") {
        uniref30_db_path = params.uniref30_db_path + "*"
    } else {
        uniref30_db_path = params.uniref30_db_path + "/*"
    }

    uniref30_db_channel = Channel.fromPath(uniref30_db_path)

    if (params.envdb_db_path[-1] == "/") {
        envdb_db_path = params.envdb_db_path + "*"
    } else {
        envdb_db_path = params.envdb_db_path + "/*"
    }

    envdb_db_channel = Channel.fromPath(envdb_db_path)

    db_channel = uniref30_db_channel.concat(envdb_db_channel).collect()
    
    ColabfoldSearchTask(
        query_channel,
        db_channel
        )

    emit:
    ColabfoldSearchTask.out
}

process ColabfoldSearchTask {
    label 'colabfold_search'
    cpus 16
    memory '120 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path query
    path db, stageAs: 'db/*'

    output:
    path "output/*.a3m", emit: msa

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/venv/bin/python /home/colabfold_search.py ${query} db output
    """
}

workflow {
    ColabfoldSearch(
        params.query,
        params.uniref30_db_path,
        params.envdb_db_path,
        params.filter,
        params.expand_eval,
        params.align_eval,
        params.diff,
        params.qsc,
        params.max_accept,
        params.pairing_strategy,
        params.db_load_mode,
        params.unpack,
        params.gpu_server
    )
}
