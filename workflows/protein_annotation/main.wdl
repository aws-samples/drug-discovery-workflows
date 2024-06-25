version 1.0

workflow ProteinAnnotation {
    input {
        File input_pdb
        File model_parameters
    }
    call ESM3FunctionAnnotationTask{
        input:
            input_pdb = input_pdb,
            model_parameters = model_parameters
    }
    output {
        File annotations = ESM3FunctionAnnotationTask.annotation_file
    } 
}

task ESM3FunctionAnnotationTask {
    input {
        File input_pdb
        Int cpu = 4
        File model_parameters
        String memory = "16 GiB"
        String docker_image = "{{esm3:latest}}"
    }
    command <<<
        set -euxo pipefail
        mkdir -p output esm
        tar -xvf ~{model_parameters} -C esm
        /opt/conda/bin/python /home/model-server/predict_annotations.py ~{input_pdb} --output_dir="output"
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        cpu: cpu
        acceleratorCount: 1,
        acceleratorType: "nvidia-tesla-a10g"
        }
    output {
        File annotation_file="output/annotations.txt"
    }
}