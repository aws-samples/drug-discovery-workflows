#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Chai1 {
    take:
        fasta_path
        num_diffn_timesteps
        num_trunk_recycles
        bond_loss_input_proj
        confidence_head
        conformers_v1
        diffusion_module
        feature_embedding
        token_embedder
        trunk
        esm2_config
        esm2_pytorch_model_00001_of_00002
        esm2_pytorch_model_00002_of_00002
        esm2_pytorch_model_bin_index
        esm2_special_tokens_map
        esm2_tokenizer_config
        esm2_vocab

    main:
    Chai1Task(
        fasta_path,
        num_diffn_timesteps,
        num_trunk_recycles,
        bond_loss_input_proj,
        confidence_head,
        conformers_v1,
        diffusion_module,
        feature_embedding,
        token_embedder,
        trunk,
        esm2_config,
        esm2_pytorch_model_00001_of_00002,
        esm2_pytorch_model_00002_of_00002,
        esm2_pytorch_model_bin_index,
        esm2_special_tokens_map,
        esm2_tokenizer_config,
        esm2_vocab
    )

    Chai1Task.out.cif.set { cif }
    Chai1Task.out.npz.set { npz }

    emit:
    cif
    npz
}

process Chai1Task {
    label 'chai1'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        each fasta_path
        val num_diffn_timesteps
        val num_trunk_recycles
        path bond_loss_input_proj
        path confidence_head
        path conformers_v1
        path diffusion_module
        path feature_embedding
        path token_embedder
        path trunk
        path esm2_config
        path esm2_pytorch_model_00001_of_00002
        path esm2_pytorch_model_00002_of_00002
        path esm2_pytorch_model_bin_index
        path esm2_special_tokens_map
        path esm2_tokenizer_config
        path esm2_vocab

    output:
    path 'output/*.cif', emit: cif
    path 'output/*.npz', emit: npz

    script:
    """
    set -euxo pipefail
    
    mkdir models_v2
    ln -t models_v2 $bond_loss_input_proj $confidence_head $diffusion_module $feature_embedding $token_embedder $trunk
    
    mkdir -p esm/models--facebook--esm2_t36_3B_UR50D/snapshots/476b639933c8baad5ad09a60ac1a87f987b656fc
    ln -t esm/models--facebook--esm2_t36_3B_UR50D/snapshots/476b639933c8baad5ad09a60ac1a87f987b656fc \
        $esm2_config $esm2_pytorch_model_00001_of_00002 \
        $esm2_pytorch_model_00002_of_00002 \
        $esm2_pytorch_model_bin_index \
        $esm2_special_tokens_map \
        $esm2_tokenizer_config \
        $esm2_vocab

    mkdir output
    CHAI_DOWNLOADS_DIR=\$(pwd) /opt/conda/bin/python /home/scripts/predict_structure.py $fasta_path \
        --num_diffn_timesteps=$num_diffn_timesteps \
        --num_trunk_recycles=$num_trunk_recycles \
        --output_dir='output' 
        
    """
}

workflow {
    Chai1(
        Channel.fromPath(params.fasta_path),
        Channel.value(params.num_diffn_timesteps),
        Channel.value(params.num_trunk_recycles),
        Channel.fromPath(params.bond_loss_input_proj),
        Channel.fromPath(params.confidence_head),
        Channel.fromPath(params.conformers_v1),
        Channel.fromPath(params.diffusion_module),
        Channel.fromPath(params.feature_embedding),
        Channel.fromPath(params.token_embedder),
        Channel.fromPath(params.trunk),
        Channel.fromPath(params.esm2_config),
        Channel.fromPath(params.esm2_pytorch_model_00001_of_00002),
        Channel.fromPath(params.esm2_pytorch_model_00002_of_00002),
        Channel.fromPath(params.esm2_pytorch_model_bin_index),
        Channel.fromPath(params.esm2_special_tokens_map),
        Channel.fromPath(params.esm2_tokenizer_config),
        Channel.fromPath(params.esm2_vocab)
    )
}
