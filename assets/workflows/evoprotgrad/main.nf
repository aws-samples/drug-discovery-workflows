nextflow.enable.dsl = 2

workflow EvoProtGrad {
    take:
    input_fasta
    plm_model_files
    preserved_regions
    output_type
    parallel_chains
    n_steps
    max_mutations

    main:
    wtseq_ch = input_fasta
        .splitFasta(record: [id: true, seqString: true])
        .filter ( record -> record.seqString.size() > 0 )

    RunDirectedEvolutionTask(
        wtseq_ch,
        plm_model_files,
        preserved_regions,
        output_type,
        parallel_chains,
        n_steps,
        max_mutations
    )
    RunDirectedEvolutionTask.out.csvs.set { csv_ch }

    emit:
    csv_ch
}

process RunDirectedEvolutionTask {
    label 'evoprotgrad'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        tuple val(wtseq_id), val(wtseq)
        path plm_model_files
        val preserved_regions
        val output_type
        val parallel_chains
        val n_steps
        val max_mutations
        
    output:
        path 'output/*.csv', emit: csvs

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/conda/bin/python /home/scripts/directed_evolution.py ${wtseq} \
        "${wtseq_id}" \
        output/ \
        --plm_expert_name_or_path=${plm_model_files} \
        --preserved_regions ${preserved_regions} \
        --output_type ${output_type} \
        --parallel_chains ${parallel_chains} \
        --n_steps ${n_steps} \
        --max_mutations ${max_mutations}
    """
}

workflow {
    EvoProtGrad(
        Channel.fromPath(params.input_fasta),
        Channel.fromPath(params.plm_model_files),
        Channel.value(params.preserved_regions),
        Channel.value(params.output_type),
        Channel.value(params.parallel_chains),
        Channel.value(params.n_steps),
        Channel.value(params.max_mutations)
    )
}