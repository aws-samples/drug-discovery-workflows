nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    RunInference(params.model_parameters, 
                 params.pdb_path,
                 params.pdb_path_chains,
                 params.num_seq_per_target,
                 params.batch_size,
                 params.max_length)
}

process RunInference {
    label 'predict'
    cpus 4
    memory "16 GB"
    accelerator 1, type: "nvidia-tesla-t4-a10g"
    publishDir "/mnt/workflow/pubdir"

    input:
        path model_parameters
        path pdb_path
        val pdb_path_chains
        val num_seq_per_target
        val batch_size
        val max_length

    output:
        path "output/*", emit: results

    script:
    """
    set -euxo pipefail
    mkdir -p output
    source /opt/venv/bin/activate
    python /opt/proteinmpnn/protein_mpnn_run.py \
        --pdb_path ${pdb_path} \
        --pdb_path_chains ${pdb_path_chains} \
        --path_to_model_weights ${model_parameters} \
        --out_folder output \
        --num_seq_per_target ${num_seq_per_target} \
        --batch_size ${batch_size} \
        --max_length ${max_length}
    """

}
