version 1.0

workflow ESM2EmbeddingsFlow {
    input {
        File fasta_path
        String model_name = "facebook/esm2_t36_3B_UR50D"
    }

    call ShardFastaTask{
        input:
            fasta_path = fasta_path,
            max_records_per_partition = 100,
            docker_image = "{{biolambda:latest}}",
    }
    scatter (fasta in ShardFastaTask.fastas){
        call ESM2EmbeddingsTask{
            input:
                fasta_path = fasta,
                model_name = model_name,
                batch_size =  24
                quant = True
                docker_image = "{{pytorch:latest}}"
        }
    }
    output {
        File embeddings = ESM2EmbeddingsTask.embeddings
    } 
}

task ShardFastaTask {
    input {
        File fasta_path
        Int cpu = 2
        String memory = "4 GiB"        
        String docker_image = "protein-utils"
        Int max_records_per_partition = 100
        String output_dir = "/home/scripts/output"
    }
    command <<<
        set -euxo pipefail
        printenv
        mkdir output
        /opt/venv/bin/python /home/scripts/split_fasta.py ~{fasta_path} --max_records_per_partition=~{max_records_per_partition} --output_dir=~{output_dir} --save_csv
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        cpu: cpu
    }
    output {
        Array[File] fastas = ~{output_dir}
    }
}

task ESM2EmbeddingsTask {
    input {
        File fasta_path
        # File model_parameters = "ref_data/esmfold_parameters_221230.tar"
        String memory = "32 GiB"
        Int cpu = 4
        String docker_image = "pytorch"
        String model_name = "facebook/esm2_t36_3B_UR50D"
        Int batch_size = 24
        String output_dir = "/home/scripts/output"
    }
    command <<<
        set -euxo pipefail
        printenv
        mkdir output
        /opt/venv/bin/python /home/scripts/generate_esm2_embeddings.py ~{fasta_path} --model_name=~{model_name} --output_file=~{output_dir}/embeddings.npy
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        acceleratorCount: 1,
        acceleratorType: "nvidia-tesla-t4-a10g",
        cpu: cpu        
    }
    output {
        File embeddings = "~{output_dir}/embeddings.npy"
    }
}

