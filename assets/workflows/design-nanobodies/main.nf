nextflow.enable.dsl = 2

include {
    RFDiffusionProteinMPNN
} from '../rfdiffusion-proteinmpnn/main'

include {
    ESMFold
} from '../esmfold/main'

workflow DesignNanobodies {
    take:
    target_pdb
    hotspot_residues
    parallel_iteration
    num_bb_designs_per_target
    num_seq_designs_per_bb
    proteinmpnn_sampling_temp
    scaffold_pdb
    scaffold_design_chain
    scaffold_design_positions
    rfdiffusion_params
    proteinmpnn_params
    proteinmpnn_model_name
    esmfold_max_records_per_partition
    esmfold_model_parameters

    main:
    RFDiffusionProteinMPNN(
        target_pdb,
        hotspot_residues,
        parallel_iteration,
        num_bb_designs_per_target,
        num_seq_designs_per_bb,
        proteinmpnn_sampling_temp,
        scaffold_pdb,
        scaffold_design_chain,
        scaffold_design_positions,
        rfdiffusion_params,
        proteinmpnn_params,
        proteinmpnn_model_name
        )

    RFDiffusionProteinMPNN.out.backbone_pdb.collect().set { generated_backbone }
    RFDiffusionProteinMPNN.out.generated_fasta.collect().set { generated_fasta }
    RFDiffusionProteinMPNN.out.generated_jsonl.collect().set { generated_jsonl }
    generated_jsonl.view()
    generated_fasta.view()

    // ESMFold(
    //     generated_fasta,
    //     esmfold_max_records_per_partition,
    //     esmfold_model_parameters
    //     )

    // ESMFold.out.pdb.collect().set { esmfold_pdb }
    // ESMFold.out.tensors.collect().set { esmfold_tensors }
    // ESMFold.out.pae_plot.collect().set { esmfold_pae_plots }
    // ESMFold.out.metrics.collect().set { esmfold_metrics }
    // ESMFold.out.combined_metrics.set { combined_esmfold_metrics }

    // CollectResultsTask(generated_jsonl, combined_esmfold_metrics)
    // CollectResultsTask.out.results.collect().set { results_ch }
    // results_ch.view()

    // emit:
    // results_ch
}

process CollectResultsTask {
    label 'utility'
    cpus 4
    memory '14 GB'
    maxRetries 2
    publishDir "/mnt/workflow/pubdir/${task.process.replace(':', '/')}/${task.index}"

    input:
    path generation_results
    path esmfold_results

    output:
    path 'results.jsonl', emit: results

    script:
    """
    set -euxo pipefail
    echo ${generation_results}
    echo ${esmfold_results}
    /opt/venv/bin/python /home/putils/src/putils/collect_results.py \
        --generation_results ${generation_results} \
        --esmfold_results ${esmfold_results}
    """
}

workflow {
    DesignNanobodies(
        Channel.fromPath(params.target_pdb),
        Channel.value(params.hotspot_residues),
        Channel.of(1..params.num_parallel_workflows),
        Channel.value(params.num_bb_designs_per_target),
        Channel.value(params.num_seq_designs_per_bb),
        Channel.value(params.proteinmpnn_sampling_temp),
        Channel.fromPath(params.scaffold_pdb),
        Channel.value(params.scaffold_design_chain),
        Channel.value(params.scaffold_design_positions),
        Channel.fromPath(params.rfdiffusion_params),
        Channel.fromPath(params.proteinmpnn_params),
        Channel.value(params.proteinmpnn_model_name),
        Channel.value(params.esmfold_max_records_per_partition),
        Channel.fromPath(params.esmfold_model_parameters)
    )
}
