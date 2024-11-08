nextflow.enable.dsl = 2

include {
    RFDiffusionProteinMPNN
} from '../rfdiffusion-proteinmpnn/main'

include {
    ESMFold
} from '../esmfold/main'

include {
    AMPLIFY
} from '../amplify-pseudo-perplexity/main'

workflow DesignNanobodies {
    take:
    target_pdb
    hotspot_residues
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
    amplify_model_parameters

    main:
    RFDiffusionProteinMPNN(
        target_pdb,
        hotspot_residues,
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

    RFDiffusionProteinMPNN.out.generated_fasta.collect().set { generated_fasta }
    RFDiffusionProteinMPNN.out.generated_jsonl.collect().set { generated_jsonl }

    ESMFold(
        generated_fasta,
        esmfold_model_parameters
        )

    ESMFold.out.combined_metrics.set { combined_esmfold_metrics }
    ESMFold.out.pdb.set { esmfold_pdb }


    AMPLIFY(
        generated_fasta,
        amplify_model_parameters
    )

    AMPLIFY.out.ppl_results.set { ppl_results }

    AdditionalResultsTask(scaffold_pdb, esmfold_pdb)
    AdditionalResultsTask.out.additional_results.collect().set { additional_results }

    CollectResultsTask(generated_jsonl, combined_esmfold_metrics, ppl_results, additional_results)
    CollectResultsTask.out.results.collect().set { results_ch }

    emit:
    results_ch
}

process AdditionalResultsTask {
    label 'utility'
    cpus 2
    memory '4 GB'
    maxRetries 1
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path scaffold_pdb
    path predicted_pdb
    
    output:
    path '*.jsonl', emit: additional_results

    script:
    """
    set -euxo pipefail
    echo ${scaffold_pdb}
    echo ${predicted_pdb}

    /opt/venv/bin/python /home/putils/src/putils/calculate_scaffold_rmsd.py \
        --scaffold_pdb ${scaffold_pdb} \
        --predicted_pdb "${predicted_pdb}"
    """
}

process CollectResultsTask {
    label 'utility'
    cpus 2
    memory '4 GB'
    maxRetries 1
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path generation_results
    path esmfold_results
    path ppl_results
    path additional_results

    output:
    path 'results.jsonl', emit: results

    script:
    """
    set -euxo pipefail
    echo ${generation_results}
    echo ${esmfold_results}
    echo ${ppl_results}
    echo ${additional_results}
    /opt/venv/bin/python /home/putils/src/putils/collect_results.py \
        --generation_results ${generation_results} \
        --esmfold_results ${esmfold_results} \
        --ppl_results ${ppl_results} \
        --additional_results ${additional_results}
    """
}

workflow {
    DesignNanobodies(
        Channel.fromPath(params.target_pdb),
        Channel.value(params.hotspot_residues),
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
        Channel.fromPath(params.esmfold_model_parameters),
        Channel.fromPath(params.amplify_model_parameters)
    )
}
