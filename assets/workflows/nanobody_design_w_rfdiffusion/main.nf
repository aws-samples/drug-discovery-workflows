nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    RunInference(
                 params.target_pdb,
                 params.scaffold_pdb,
                 params.hotspot_residues,
                 params.num_str_designs_per_target,
                 params.num_seq_designs_per_str,
                 params.complex_Fold_base_ckpt,
                 params.proteinmpnn_ckpt
                 )
}

process RunInference {
    label 'predict'
    cpus 8
    memory '24 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    input:
        path target_pdb
        path scaffold_pdb
        val hotspot_residues
        val num_str_designs_per_target
        val num_seq_designs_per_str
        path complex_Fold_base_ckpt
        path proteinmpnn_ckpt

    output:
        path 'seqs', emit: seq_results
        path 'str', emit: str_results
        path 'scores', emit: score_results
        path 'misc', emit: misc_results

    script:
    """
    set -euxo pipefail
    mkdir seqs str scores misc
    export HYDRA_FULL_ERROR=1

    echo "Generating secondary structure and adjacency inputs for fold conditioning"

    /opt/conda/bin/python3 /opt/rfdiffusion/helper_scripts/make_secstruc_adj.py \
        --input_pdb ${scaffold_pdb} --out_dir secstruc/scaffold
    /opt/conda/bin/python3 /opt/rfdiffusion/helper_scripts/make_secstruc_adj.py \
        --input_pdb ${target_pdb} --out_dir secstruc/target

    echo "Generating backbone structures with RFDiffusion"

    /opt/conda/bin/python3 /opt/rfdiffusion/scripts/run_inference.py \
        inference.output_prefix=str/output \
        inference.model_directory_path='.' \
        inference.input_pdb=${target_pdb} \
        'ppi.hotspot_res=${hotspot_residues}' \
        scaffoldguided.scaffoldguided=True \
        scaffoldguided.mask_loops=False \
        scaffoldguided.target_path=${target_pdb} \
        scaffoldguided.target_pdb=True \
        scaffoldguided.target_ss=secstruc/target/${target_pdb.baseName}_ss.pt \
        scaffoldguided.target_adj=secstruc/target/${target_pdb.baseName}_adj.pt \
        scaffoldguided.scaffold_dir=secstruc/scaffold \
        inference.num_designs=${num_str_designs_per_target} \
        denoiser.noise_scale_ca=0.5 \
        denoiser.noise_scale_frame=0.5

    echo "Generating sequence candidates with proteinmpnn"

    folder_with_pdbs="str"
    path_for_parsed_chains="misc/parsed_pdbs.jsonl"
    path_for_assigned_chains="misc/assigned_pdbs.jsonl"
    path_for_fixed_positions="misc/fixed_pdbs.jsonl"
    chains_to_design="A"
    design_only_positions="26 27 28 29 30 31 32 33 34 35 55 56 57 58 59 60 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117"

    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/parse_multiple_chains.py \
        --input_path=\$folder_with_pdbs --output_path=\$path_for_parsed_chains
    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/assign_fixed_chains.py \
        --input_path=\$path_for_parsed_chains --output_path=\$path_for_assigned_chains \
        --chain_list \$chains_to_design
    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/make_fixed_positions_dict.py \
        --input_path=\$path_for_parsed_chains --output_path=\$path_for_fixed_positions \
        --chain_list "\$chains_to_design" --position_list "\$design_only_positions" --specify_non_fixed

    /opt/conda/bin/python3 /opt/proteinmpnn/protein_mpnn_run.py \
        --jsonl_path \$path_for_parsed_chains \
        --chain_id_jsonl \$path_for_assigned_chains \
        --fixed_positions_jsonl \$path_for_fixed_positions \
        --path_to_model_weights="." \
        --model_name="abmpnn" \
        --num_seq_per_target=${num_seq_designs_per_str} \
        --save_score=1 \
        --out_folder "output" \
        --sampling_temp "0.1" \
        --batch_size 4
    """

    stub:
    '''
    set -euxo pipefail
    mkdir -p misc scores seqs str/traj
    touch \
        misc/assigned_pdbs.jsonl \
        misc/fixed_pdbs.jsonl \
        misc/parsed_pdbs.jsonl \
        scores/output_0.npz \
        scores/output_1.npz \
        seqs/output_0.fa \
        seqs/output_1.fa \
        str/output_0.pdb \
        str/output_0.trb \
        str/output_1.pdb \
        str/output_1.trb \
        str/output_1.trb \
        str/traj/output_0_Xt-1_traj.pdb \
        str/traj/output_0_pX0_traj.pdb \
        str/traj/output_1_Xt-1_traj.pdb \
        str/traj/output_1_pX0_traj.pdb
    '''
}
