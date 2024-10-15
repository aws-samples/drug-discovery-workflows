nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    RunInference(params.suppress_print,
                 params.ca_only,
                 params.path_to_model_weights, 
                 params.model_name,
                 params.use_soluble_model,
                 params.seed,
                 params.save_score,
                 params.save_probs,
                 params.score_only,
                 params.path_to_fasta,
                 params.conditional_probs_only,
                 params.conditional_probs_only_backbone,
                 params.unconditional_probs_only,
                 params.backbone_noise,
                 params.num_seq_per_target,
                 params.batch_size,
                 params.max_length,
                 params.sampling_temp,
                 params.out_folder
                 params.pdb_path,
                 params.pdb_path_chains,
                 params.jsonl_path,
                 params.chain_id_jsonl,
                 params.fixed_positions_jsonl,
                 params.omit_AAs,
                 params.bias_AA_jsonl,
                 params.bias_by_res_jsonl,
                 params.omit_AA_jsonl,
                 params.pssm_jsonl,
                 params.pssm_multi,
                 params.pssm_threshold,
                 params.pssm_log_odds_flag,
                 params.pssm_bias_flag,
                 params.tied_positions_jsonl)
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
