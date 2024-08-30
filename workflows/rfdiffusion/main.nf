nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    RunInference(params.model_parameters,
                 params.input_pdb,
                 params.num_designs)
}

process RunInference {
    label 'predict'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path model_parameters
        path input_pdb
        val num_designs
        path yaml_file optional true

    output:
        path 'output/*', emit: results

    script:
    """
    set -euxo pipefail
    mkdir -p output
    export HYDRA_FULL_ERROR=1 

    if [ -f "${yaml_file}" ]; then
        # Use the YAML file for configuration
        python3.9 /app/RFdiffusion/scripts/run_inference.py --config ${yaml_file}
    else
        # Use individual arguments
        python3.9 /app/RFdiffusion/scripts/run_inference.py \
            inference.output_prefix=output/rfdiffusion \
            inference.model_directory_path=${model_parameters} \
            inference.input_pdb=${input_pdb} \
            inference.num_designs=${num_designs} \
            'contigmap.contigs=[10-40/A163-181/10-40]'
    fi
    """
}
