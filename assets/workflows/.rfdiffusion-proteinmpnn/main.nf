nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    RunInference(
                 params.input_pdb,
                 params.config_file,
                 params.base_ckpt,
                 params.complex_base_ckpt,
                 params.complex_Fold_base_ckpt,
                 params.inpaintSeq_ckpt,
                 params.inpaintSeq_Fold_ckpt,
                 params.activeSite_ckpt,
                 params.base_epoch8_ckpt,
                 params.complex_beta_ckpt
                 )
}

// Configuration options
// https://github.com/RosettaCommons/RFdiffusion/blob/main/config/inference/base.yaml

process RunInference {
    label 'predict'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path input_pdb
        path config_file
        path base_ckpt
        path complex_base_ckpt
        path complex_Fold_base_ckpt
        path inpaintSeq_ckpt
        path inpaintSeq_Fold_ckpt
        path activeSite_ckpt
        path base_epoch8_ckpt
        path complex_beta_ckpt

    output:
        path 'output/*', emit: results

    script:
    """
    set -euxo pipefail
    mkdir output model config
    export HYDRA_FULL_ERROR=1

    cp ${config_file} config
    cp ${base_ckpt} ${complex_base_ckpt} \
      ${complex_Fold_base_ckpt} ${inpaintSeq_ckpt} \
      ${inpaintSeq_Fold_ckpt} ${activeSite_ckpt} \
      ${base_epoch8_ckpt} ${complex_beta_ckpt} model

    /opt/conda/bin/python3 /opt/rfdiffusion/scripts/run_inference.py \
        --config-dir config \
        --config-name ${config_file.baseName} \
        inference.output_prefix=output/rfdiffusion \
        inference.model_directory_path=rfdiffusion/model \
        inference.input_pdb=${input_pdb}

    for input_filename in output/*.pdb; do
        filename=$(basename ${input_filename})
        echo ${filename}
        python3 proteinmpnn/protein_mpnn_run.py \
        --path_to_model_weights="proteinmpnn/vanilla_model_weights" \
        --num_seq_per_target=8 \
        --pdb_path=${input_filename} \
        --save_score=1 \
        --out_folder="output/${filename%%.*}"
        mv ${input_filename} output/${filename%%.*}
    done
    """
}

process RunInference {
    label 'predict'
    cpus 4
    memory "16 GB"
    accelerator 1, type: "nvidia-tesla-t4-a10g"
    publishDir "/mnt/workflow/pubdir"

    input:
        val suppress_print
        val ca_only
        path path_to_model_weights
        val model_name
        val use_soluble_model
        val seed
        val save_score
        val save_probs
        val score_only
        path path_to_fasta
        val conditional_probs_only
        val conditional_probs_only_backbone
        val unconditional_probs_only
        val backbone_noise
        val num_seq_per_target
        val batch_size
        val max_length
        val sampling_temp
        val out_folder
        path pdb_path
        val pdb_path_chains
        path jsonl_path
        path chain_id_jsonl
        path fixed_positions_jsonl
        val omit_AAs
        path bias_AA_jsonl
        path bias_by_res_jsonl
        path omit_AA_jsonl
        path pssm_jsonl
        path pssm_multi
        val pssm_threshold
        val pssm_log_odds_flag
        val pssm_bias_flag
        path tied_positions_jsonl

    container params.container_image

    output:
        path "output/*", emit: results

    script:
    """
    set -euxo pipefail
    mkdir -p output
    source /opt/venv/bin/activate
    python /opt/proteinmpnn/protein_mpnn_run.py \
        --suppress_print ${suppress_print} \
        --ca_only ${ca_only} \
        --path_to_model_weights ${path_to_model_weights} \
        --model_name ${model_name} \
        --use_soluble_model ${use_soluble_model} \
        --seed ${seed} \
        --save_score ${save_score} \
        --save_probs ${save_probs} \
        --score_only ${score_only} \
        --path_to_fasta ${path_to_fasta} \
        --conditional_probs_only ${conditional_probs_only} \
        --conditional_probs_only_backbone ${conditional_probs_only_backbone} \
        --unconditional_probs_only ${unconditional_probs_only} \
        --backbone_noise ${backbone_noise} \
        --num_seq_per_target ${num_seq_per_target} \
        --batch_size ${batch_size} \
        --max_length ${max_length} \
        --sampling_temp ${sampling_temp} \
        --out_folder ${out_folder} \
        --pdb_path ${pdb_path} \
        --pdb_path_chains ${pdb_path_chains} \
        --jsonl_path ${jsonl_path} \
        --chain_id_jsonl ${chain_id_jsonl} \
        --fixed_positions_jsonl ${fixed_positions_jsonl} \
        --omit_AAs ${omit_AAs} \
        --bias_AA_jsonl ${bias_AA_jsonl} \
        --bias_by_res_jsonl ${bias_by_res_jsonl} \
        --omit_AA_jsonl ${omit_AA_jsonl} \
        --pssm_jsonl ${pssm_jsonl} \
        --pssm_multi ${pssm_multi} \
        --pssm_threshold ${pssm_threshold} \
        --pssm_log_odds_flag ${pssm_log_odds_flag} \
        --pssm_bias_flag ${pssm_bias_flag} \
        --tied_positions_jsonl ${tied_positions_jsonl} \
    """

}
