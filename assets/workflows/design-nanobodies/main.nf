nextflow.enable.dsl = 2

include {
    ESMFoldTask
} from '../esmfold'

include {
    GenerateCandidatesTask
} from '../rfdiffusion-proteinmpnn'

workflow DesignNanobodies {
    target_ch = Channel.fromPath(params.target_pdb)
    scaffold_ch = Channel.fromPath(params.scaffold_pdb)
    rfdiffusion_params_ch = Channel.fromPath(params.rfdiffusion_model_parameters)
    proteinmpnn_params_ch = Channel.fromPath(params.proteinmpnn_model_parameters)
    esmfold_params_ch = Channel.fromPath(params.esmfold_model_parameters)

    GenerateCandidatesTask(
                 target_ch,
                 scaffold_ch,
                 params.hotspot_residues,
                 params.num_str_designs_per_target,
                 params.num_seq_designs_per_str,
                 rfdiffusion_params_ch,
                 proteinmpnn_params_ch,
                 params.proteinmpnn_model_name
                 )

    GenerateCandidatesTask.out.backbones.collect().set { backbone_ch }
    GenerateCandidatesTask.out.generated_fasta.collect().set { fasta_ch }
    GenerateCandidatesTask.out.generated_jsonl.collect().set { jsonl_ch }

    ESMFoldTask(fasta_ch, esmfold_params_ch)
    ESMFoldTask.out.output.collect().set { esmfold_ch }

    emit:
    backbone_structures = backbone_ch
    generated_fasta = fasta_ch
    generated_jsonline = jsonl_ch
    esmfold_structures = esmfold_ch
}

workflow {
    DesignNanobodies()
}
