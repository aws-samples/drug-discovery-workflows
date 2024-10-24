nextflow.enable.dsl = 2

workflow DesignNanobodies {
    target_ch = Channel.fromPath(params.target_pdb)
    scaffold_ch = Channel.fromPath(params.scaffold_pdb)
    rfdiffusion_params_ch = Channel.fromPath(params.complex_Fold_base_ckpt)
    proteinmpnn_params_ch = Channel.fromPath(params.proteinmpnn_ckpt)

    GenerateCandidates(
                 target_ch,
                 scaffold_ch,
                 params.hotspot_residues,
                 params.num_str_designs_per_target,
                 params.num_seq_designs_per_str,
                 rfdiffusion_params_ch,
                 proteinmpnn_params_ch,
                 params.proteinmpnn_model_name
                 )

    GenerateCandidates.out.output.collect().set { output_ch }

    emit:
    output = output_ch
}

process GenerateCandidates {
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
        val proteinmpnn_model_name

    output:
        path 'output/', emit: output

    script:
    """
    set -euxo pipefail
    mkdir output
    export HYDRA_FULL_ERROR=1

    echo "Generating secondary structure and adjacency inputs for fold conditioning"

    /opt/conda/bin/python3 /opt/rfdiffusion/helper_scripts/make_secstruc_adj.py \
        --input_pdb ${scaffold_pdb} --out_dir output
    /opt/conda/bin/python3 /opt/rfdiffusion/helper_scripts/make_secstruc_adj.py \
        --input_pdb ${target_pdb} --out_dir output

    echo "Generating backbone structures with RFDiffusion"

    /opt/conda/bin/python3 /opt/rfdiffusion/scripts/run_inference.py \
        inference.output_prefix=output/backbone \
        inference.model_directory_path='/opt/data' \
        inference.input_pdb=${target_pdb} \
        'ppi.hotspot_res=[E492, E493, E494, E495, E496, E497]' \
        scaffoldguided.scaffoldguided=True \
        scaffoldguided.mask_loops=False \
        scaffoldguided.target_path=${target_pdb} \
        scaffoldguided.target_pdb=True \
        scaffoldguided.target_ss=output/6m0j_ss.pt \
        scaffoldguided.target_adj=output/6m0j_adj.pt \
        scaffoldguided.scaffold_dir=output \
        inference.num_designs=${num_str_designs_per_target} \
        denoiser.noise_scale_ca=0.5 \
        denoiser.noise_scale_frame=0.5

    echo "Generating sequence candidates with proteinmpnn"

    cp ${proteinmpnn_ckpt} /opt/proteinmpnn/vanilla_model_weights

    folder_with_pdbs="output"
    path_for_parsed_chains="output/parsed_pdbs.jsonl"
    path_for_assigned_chains="output/assigned_pdbs.jsonl"
    path_for_fixed_positions="output/fixed_pdbs.jsonl"
    chains_to_design="A"
    design_only_positions="26 27 28 29 30 31 32 33 34 35 55 56 57 58 59 60 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117"

    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/parse_multiple_chains.py \
        --input_path=$folder_with_pdbs --output_path=$path_for_parsed_chains
    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/assign_fixed_chains.py \
        --input_path=$path_for_parsed_chains --output_path=$path_for_assigned_chains \
        --chain_list $chains_to_design
    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/make_fixed_positions_dict.py \
        --input_path=$path_for_parsed_chains --output_path=$path_for_fixed_positions \
        --chain_list "$chains_to_design" --position_list "$design_only_positions" --specify_non_fixed

    /opt/conda/bin/python3 /opt/proteinmpnn/protein_mpnn_run.py \
        --jsonl_path $path_for_parsed_chains \
        --chain_id_jsonl $path_for_assigned_chains \
        --fixed_positions_jsonl $path_for_fixed_positions \
        --model_name ${proteinmpnn_model_name} \
        --num_seq_per_target=${num_seq_designs_per_str} \
        --out_folder "output" \
        --sampling_temp "0.1" \
        --batch_size 4

    /opt/conda/bin/python3 /opt/scripts/collect_designs.py \
        --scaffold_pdb=${scaffold_pdb} \
        --design_only_positions="$design_only_positions" \
        --seq_dir="output/seqs" \
        --output_path="generated_sequences"
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

workflow {
    DesignNanobodies()
}