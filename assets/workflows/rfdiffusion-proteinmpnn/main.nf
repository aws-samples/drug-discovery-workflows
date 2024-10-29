nextflow.enable.dsl = 2

workflow RFDiffusionProteinMPNN {
    take:
    target_pdb
    hotspot_residues
    parallel_iteration
    num_bb_designs_per_target
    num_seq_designs_per_bb
    proteinmpnn_sampling_temp
    scaffold_pdb
    scaffold_design_chain
    scaffold_design_positions
    rfdiffusion_params
    proteinmpnn_params
    proteinmpnn_model_name

    main:
    GenerateCandidatesTask(
        target_pdb,
        hotspot_residues,
        parallel_iteration,
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
    GenerateCandidatesTask.out.backbones.collect().set { backbone_pdb }
    GenerateCandidatesTask.out.generated_fasta.collect().set { generated_fasta }
    GenerateCandidatesTask.out.generated_jsonl.collect().set { generated_jsonl }

    emit:
    target_pdb
    scaffold_pdb
    backbone_pdb
    generated_fasta
    generated_jsonl
}

process GenerateCandidatesTask {
    label 'rfdiffusion'
    cpus 8
    memory '30 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${task.process.replace(':', '/')}/${task.index}"

    input:
        path target_pdb
        val hotspot_residues
        each parallel_iteration
        val num_bb_designs_per_target
        val num_seq_designs_per_bb
        val proteinmpnn_sampling_temp
        path scaffold_pdb
        val scaffold_design_chain
        val scaffold_design_positions
        path rfdiffusion_params
        path proteinmpnn_params
        val proteinmpnn_model_name

    output:
        path target_pdb, emit: target_pdb
        path scaffold_pdb, emit: scaffold_pdb
        path 'backbones/bb*.pdb', emit: backbones
        path 'seq*.fa', emit: generated_fasta
        path 'seq*.jsonl', emit: generated_jsonl

    script:
    """
    set -euxo pipefail

    export HYDRA_FULL_ERROR=1

    echo "Task id ${task.index}"
    echo "Task process ${task.process}"

    echo "Generating secondary structure and adjacency inputs for fold conditioning"

    /opt/conda/bin/python3 /opt/rfdiffusion/helper_scripts/make_secstruc_adj.py \
        --input_pdb ${scaffold_pdb} --out_dir .
    /opt/conda/bin/python3 /opt/rfdiffusion/helper_scripts/make_secstruc_adj.py \
        --input_pdb ${target_pdb} --out_dir .

    echo "Generating backbone structures with RFDiffusion"

    BB_PDB_DIR="backbones"

    /opt/conda/bin/python3 /opt/rfdiffusion/scripts/run_inference.py \
        inference.output_prefix=\$BB_PDB_DIR/bb \
        inference.model_directory_path='.' \
        inference.input_pdb=${target_pdb} \
        'ppi.hotspot_res=${hotspot_residues}' \
        scaffoldguided.scaffoldguided=True \
        scaffoldguided.mask_loops=False \
        scaffoldguided.target_path=${target_pdb} \
        scaffoldguided.target_pdb=True \
        scaffoldguided.target_ss=${target_pdb.baseName}_ss.pt \
        scaffoldguided.target_adj=${target_pdb.baseName}_adj.pt \
        scaffoldguided.scaffold_dir="." \
        inference.num_designs=${num_bb_designs_per_target} \
        denoiser.noise_scale_ca=0.5 \
        denoiser.noise_scale_frame=0.5

    echo "Preparing secondary structure and adjacency files for generation context"

    cp ${proteinmpnn_params} /opt/proteinmpnn/vanilla_model_weights

    PATH_FOR_PARSED_CHAINS="parsed_pdbs.jsonl"
    PATH_FOR_ASSIGNED_CHAINS="assigned_pdbs.jsonl"
    PATH_FOR_FIXED_POSITIONS="fixed_pdbs.jsonl"

    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/parse_multiple_chains.py \
        --input_path=\$BB_PDB_DIR --output_path=\$PATH_FOR_PARSED_CHAINS
    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/assign_fixed_chains.py \
        --input_path=\$PATH_FOR_PARSED_CHAINS --output_path=\$PATH_FOR_ASSIGNED_CHAINS \
        --chain_list ${scaffold_design_chain}
    /opt/conda/bin/python3 /opt/proteinmpnn/helper_scripts/make_fixed_positions_dict.py \
        --input_path=\$PATH_FOR_PARSED_CHAINS --output_path=\$PATH_FOR_FIXED_POSITIONS \
        --chain_list "${scaffold_design_chain}" --position_list "${scaffold_design_positions}" --specify_non_fixed

    echo "Generating sequences with proteinmpnn"

    /opt/conda/bin/python3 /opt/proteinmpnn/protein_mpnn_run.py \
        --jsonl_path \$PATH_FOR_PARSED_CHAINS \
        --chain_id_jsonl \$PATH_FOR_ASSIGNED_CHAINS \
        --fixed_positions_jsonl \$PATH_FOR_FIXED_POSITIONS \
        --model_name ${proteinmpnn_model_name} \
        --num_seq_per_target=${num_seq_designs_per_bb} \
        --out_folder "." \
        --sampling_temp "${proteinmpnn_sampling_temp}" \
        --batch_size 8

    ls -loh

    /opt/conda/bin/python3 /opt/scripts/collect_designs.py \
        --scaffold_pdb=${scaffold_pdb} \
        --design_only_positions="${scaffold_design_positions}" \
        --seq_dir="seqs" \
        --output_path=seq-"${task.index}"

    ls -loh

    """
}

workflow {
    RFDiffusionProteinMPNN(
        Channel.fromPath(params.target_pdb),
        Channel.value(params.hotspot_residues),
        Channel.of(1..params.num_parallel_workflows),
        Channel.value(params.num_bb_designs_per_target),
        Channel.value(params.num_seq_designs_per_bb),
        Channel.value(params.proteinmpnn_sampling_temp),
        Channel.fromPath(params.scaffold_pdb),
        Channel.value(params.scaffold_design_chain),
        Channel.value(params.scaffold_design_positions),
        Channel.fromPath(params.rfdiffusion_params),
        Channel.fromPath(params.proteinmpnn_params),
        Channel.value(params.proteinmpnn_model_name)
    )
}
