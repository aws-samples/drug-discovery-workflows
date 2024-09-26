nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    RunInference(params.model_params, 
                 params.input_pdb,
                 params.contigs,
                 params.num_designs,
                 params.yaml_file)
}

// Configuration options
// https://github.com/RosettaCommons/RFdiffusion/blob/main/config/inference/base.yaml

process RunInference {
    label 'predict'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    // contigs, num_designs, yaml_file are optional, because we can pass a yaml file to set
    input:
        path model_params
        path input_pdb
        val contigs
        val num_designs
        path yaml_file

    container params.container_image

    output:
        path 'output/*', emit: results

    script:
    """
    set -euxo pipefail
    mkdir -p output
    export HYDRA_FULL_ERROR=1 

    if [ -f "${yaml_file}" ]; then
        # Use the YAML file for configuration
        python3.9 /app/RFdiffusion/scripts/run_inference.py \
            --config-path . \
            --config-name ${yaml_file.baseName} \
            inference.output_prefix=output/rfdiffusion \
            inference.model_directory_path=${model_params} \
            inference.input_pdb=${input_pdb}
    else
        # Use individual arguments
        python3.9 /app/RFdiffusion/scripts/run_inference.py \
            inference.output_prefix=output/rfdiffusion \
            inference.model_directory_path=${model_params} \
            inference.input_pdb=${input_pdb} \
            inference.num_designs=${num_designs} \
            contigmap.contigs=${contigs}
    fi
    """
}
