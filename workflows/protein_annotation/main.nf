nextflow.enable.dsl = 2

params.input_pdb
params.model_parameters

workflow {

    ESM3FunctionAnnotationTask(
        params.input_pdb,
        params.model_parameters
    )
}

process ESM3FunctionAnnotationTask {
    cpus 4
    memory '16GB'
    container '{{esm3:latest}}'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path input_pdb
        path model_parameters

    output:
        path 'output/annotations.txt', emit: annotation_file

    script:
    """
    set -euxo pipefail
    mkdir -p output esm
    tar -xvf ${model_parameters} -C esm
    /opt/conda/bin/python /home/model-server/predict_annotations.py ${input_pdb} --output_dir="output"
    """
}
