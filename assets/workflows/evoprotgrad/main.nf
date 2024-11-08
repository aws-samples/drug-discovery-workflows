nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    wtseq_ch = Channel.fromPath(params.input_fasta)
        .splitFasta(record: [id: true, seqString: true])
        .filter ( record -> record.seqString.size() > 0 )
    RunDirectedEvolution(
        wtseq_ch,
        params.plm_model_files,
        params.onehotcnn_model_files,
        params.preserved_regions,
        params.output_type,
        params.parallel_chains,
        params.n_steps,
        params.max_mutations
    )

}


process RunDirectedEvolution {
    container '588738610715.dkr.ecr.us-east-1.amazonaws.com/evo-prot-grad-input-fasta:latest'
    cpus 8
    memory '30 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir/de'

    input:
        tuple val(wtseq_id), val(wtseq)
        path plm_model_files
        path onehotcnn_model_files
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
        ${wtseq_id}\
        output/ \
        --plm_expert_name_or_path=${plm_model_files} \
        --scorer_expert_name_or_path=${onehotcnn_model_files} \
        --preserved_regions ${preserved_regions}\
        --output_type ${output_type}\
        --parallel_chains ${parallel_chains}\
        --n_steps ${n_steps}\
        --max_mutations ${max_mutations}
    """
}
