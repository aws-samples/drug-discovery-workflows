nextflow.enable.dsl = 2

include {
    ESMFoldTask
} from '../esmfold'

include {
    GenerateCandidatesTask
} from '../rfdiffusion-proteinmpnn'

workflow DesignNanobodies {
    parallel_generation_ch = Channel.of(1..params.num_parallel_workflows)
    target_ch = Channel.fromPath(params.target_pdb)
    scaffold_ch = Channel.fromPath(params.scaffold_pdb)
    rfdiffusion_params_ch = Channel.fromPath(params.rfdiffusion_model_parameters)
    proteinmpnn_params_ch = Channel.fromPath(params.proteinmpnn_model_parameters)
    esmfold_params_ch = Channel.fromPath(params.esmfold_model_parameters)

    GenerateCandidatesTask(
        parallel_generation_ch,
        target_ch,
        scaffold_ch,
        params.hotspot_residues,
        params.num_str_designs_per_target,
        params.num_seq_designs_per_str,
        rfdiffusion_params_ch,
        proteinmpnn_params_ch,
        params.proteinmpnn_model_name
        )
    GenerateCandidatesTask.out.target_pdb.collect().set { target_ch }
    GenerateCandidatesTask.out.scaffold_pdb.collect().set { scaffold_ch }
    GenerateCandidatesTask.out.backbones.collect().set { backbone_ch }
    GenerateCandidatesTask.out.generated_fasta.collect().set { fasta_ch }
    GenerateCandidatesTask.out.generated_jsonl.collect().set { jsonl_ch }

    ESMFoldTask(fasta_ch, esmfold_params_ch)
    ESMFoldTask.out.output.collect().set { esmfold_ch }

    CollectResultsTask(jsonl_ch, esmfold_ch)
    CollectResultsTask.out.results.collect().set { results_ch }

    emit:
    target_pdb = target_ch
    scaffold_pdb = scaffold_ch
    backbone_structures = backbone_ch
    generated_fasta = fasta_ch
    generated_jsonline = jsonl_ch
    esmfold_structures = esmfold_ch
    results = results_ch
}

process CollectResultsTask {
    label 'utility'
    cpus 4
    memory '14 GB'
    maxRetries 2
    publishDir '/mnt/workflow/pubdir'

    input:
    path generation_results
    path esmfold_results

    output:
    path 'results.jsonl', emit: results

    script:
    """
    set -euxo pipefail
    /opt/venv/bin/python /home/putils/src/putils/collect_results.py \
        --generation_results ${generation_results} \
        --esmfold_results ${esmfold_results}
    """
}

workflow {
    DesignNanobodies()
}
