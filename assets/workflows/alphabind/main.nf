nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    TrainAlphaBind(
        params.input_training_data,
        params.esm2nv_path,
        params.tx_model_path,
        params.tokenizer_path,
        params.max_epochs
    )

    SequenceOptimization(
        TrainAlphaBind.out.model,
        params.esm2nv_path,
        params.tokenizer_path,
        params.seed_sequence,
        params.mutation_start_idx,
        params.mutation_end_idx,
        params.num_seeds,
        params.num_generations,
        params.target_protein_sequence,
        params.generator_type
    )
}

process TrainAlphaBind {
    label 'alphabind_container'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir/train'

    input:
        path input_training_data
        path esm2nv_path
        path tx_model_path
        path tokenizer_path
        val max_epochs

    output:
        path 'model/*.pt', emit: model

    script:
    """
    set -euxo pipefail
    export BIONEMO_HOME=/workspace/bionemo
    export HF_HOME=${tokenizer_path}
    export TRANSFORMERS_OFFLINE=1
    export HF_DATASETS_OFFLINE=1 
    export HF_HUB_OFFLINE=1
    mkdir -p /workspace/bionemo/models/
    cp ${esm2nv_path} /workspace/bionemo/models/
    mkdir embeddings model
    python -m alphabind.features.build_features --input_filepath ${input_training_data} --output_filepath train_data_featurized.csv --embedding_dir_path ./embeddings/
    python -m alphabind.models.train_model --dataset_csv_path train_data_featurized.csv --tx_model_path ${tx_model_path} --max_epochs ${max_epochs} --output_model_path model/alphabind_trained_model.pt
    """
}

process SequenceOptimization {
    label 'alphabind_container'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir/generation'

    input:
        path trained_model_path
        path esm2nv_path
        path tokenizer_path
        val seed_sequence
        val mutation_start_idx
        val mutation_end_idx
        val num_seeds
        val num_generations
        val target_protein_sequence
        val generator_type

    output:
        path 'out/*.csv', emit: generatedseqs
    
    script:
    """
    set -euxo pipefail
    export HF_HOME=${tokenizer_path}
    export TRANSFORMERS_OFFLINE=1
    export HF_DATASETS_OFFLINE=1 
    export HF_HUB_OFFLINE=1 
    mkdir -p /workspace/bionemo/models/
    cp ${esm2nv_path} /workspace/bionemo/models/
    mkdir optimization_steps out
    python -m alphabind.optimizers.optimize_seeds --batch_size 16 --save_intermediate_steps optimization_steps --generator_type ${generator_type} --seed_sequence ${seed_sequence} --mutation_start_idx ${mutation_start_idx} --mutation_end_idx ${mutation_end_idx} --target ${target_protein_sequence}  --num_seeds ${num_seeds} --generations ${num_generations} --trained_model_path ${trained_model_path} --output_file_path out/last_generation_optimized_seqs.csv 
    python -m alphabind.optimizers.merge_all_generations --intermediate_steps_path optimization_steps --num_generations ${num_generations} --output_file_path out/all_unique_candidates.csv
    """
}

