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

include {
    NanoBodyBuilder2
} from '../nanobodybuilder2/main'

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
    nanobodybuilder2_model_parameters_1
    nanobodybuilder2_model_parameters_2
    nanobodybuilder2_model_parameters_3
    nanobodybuilder2_model_parameters_4

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

    ESMFold.out.esmfold_metrics.set { esmfold_metrics }
    ESMFold.out.pdb.set { esmfold_pdb }


    AMPLIFY(
        generated_fasta,
        amplify_model_parameters
    )

    AMPLIFY.out.ppl_results.set { ppl_results }

    NanoBodyBuilder2(
        generated_fasta,
        nanobodybuilder2_model_parameters_1,
        nanobodybuilder2_model_parameters_2,
        nanobodybuilder2_model_parameters_3,
        nanobodybuilder2_model_parameters_4        
    )

    NanoBodyBuilder2.out.nanobodybuilder2_metrics.set { nanobodybuilder2_metrics }
    NanoBodyBuilder2.out.pdb.set { nanobodybuilder2_pdb }

    AdditionalResultsTask(scaffold_pdb, nanobodybuilder2_pdb)
    AdditionalResultsTask.out.additional_results.collect().set { additional_results }

    CollectResultsTask(generated_jsonl, esmfold_metrics, ppl_results, nanobodybuilder2_metrics, additional_results)
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
    path nanobodybuilder2_results
    path additional_results

    output:
    path 'results.jsonl', emit: results

    script:
    """
    set -euxo pipefail
    echo ${generation_results}
    echo ${esmfold_results}
    echo ${ppl_results}
    echo ${nanobodybuilder2_results}
    echo ${additional_results}
    /opt/venv/bin/python /home/putils/src/putils/collect_results.py \
        --generation_results ${generation_results} \
        --esmfold_results ${esmfold_results} \
        --ppl_results ${ppl_results} \
        --nanobodybuilder2_results ${nanobodybuilder2_results} \
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
        Channel.fromPath(params.amplify_model_parameters),
        Channel.fromPath(params.nanobodybuilder2_model_parameters_1),
        Channel.fromPath(params.nanobodybuilder2_model_parameters_2),
        Channel.fromPath(params.nanobodybuilder2_model_parameters_3),
        Channel.fromPath(params.nanobodybuilder2_model_parameters_4)
    )
}
