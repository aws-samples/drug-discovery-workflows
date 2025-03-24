#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow ColabfoldSearch {
    take:
        query
        uniref30_db_path
        envdb_db_path
        pdb100_db_path
        is_complex
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

    if (params.pdb100_db_path[-1] == "/") {
        pdb100_db_path = params.pdb100_db_path + "*"
    } else {
        pdb100_db_path = params.pdb100_db_path + "/*"
    }

    pdb100_db_channel = Channel.fromPath(pdb100_db_path)

    db_channel = uniref30_db_channel.concat(envdb_db_channel, pdb100_db_channel).collect()

    ColabfoldSearchTask(
        query,
        db_channel,
        is_complex
        )

    ColabfoldSearchTask.out.msa.collect().set { msa }
    ColabfoldSearchTask.out.template_hits.collect().set { template_hits }


    emit:
    msa
    template_hits
}

process ColabfoldSearchTask {
    label 'colabfold_search'
    cpus 64
    memory '480 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-l40s'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path query
    path db, stageAs: 'db/*'
    val is_complex

    output:
    path "*.a3m", emit: msa
    path "*.m8", emit: template_hits

    script:
    """
    set -euxo pipefail
    # mkdir output

    # Remove any model-specific content in the description

    # Produces a new, "clean.fasta" file
    bash /home/clean_fasta.sh ${query} 

    bash /home/msa.sh \
      /usr/local/bin/mmseqs \
      clean.fasta \
      . \
      db/uniref30_2302_db \
      db/pdb100_230517 \
      db/colabfold_envdb_202108_db \
      1 1 1 0 0 1

    if [[ ${is_complex} -eq 1 ]]; then
      bash /home/pair.sh \
        /usr/local/bin/mmseqs \
        clean.fasta \
        . \
        db/uniref30_2302_db \
        "" 0 1 0 1
    fi

    rm clean.fasta

    """
}

workflow {
    ColabfoldSearch(
        params.query,
        params.uniref30_db_path,
        params.envdb_db_path,
        params.pdb100_db_path,
        params.is_complex,
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
