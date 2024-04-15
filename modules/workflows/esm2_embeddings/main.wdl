version 1.0

workflow ESM2EmbeddingsFlow {
    input {
        File fasta_path
        String model_name = "esm2_t6_8M_UR50D"
        File model_parameters = "s3://167428594774-us-east-1-aho/models/esm/esm2_t6_8M_UR50D.tar"
    }

    call ShardFastaTask{
        input:
            fasta_path = fasta_path,
            max_records_per_partition = 100,
            docker_image = "biolambda:latest",
    }
    call ESM2EmbeddingsTask{
        input:
            csv_path = ShardFastaTask.csv,
            model_parameters = model_parameters,
            model_name = model_name,
            batch_size =  24,
            docker_image = "pytorch:latest"
    }
    # scatter (csv in ShardFastaTask.csvs){
    #     call ESM2EmbeddingsTask{
    #         input:
    #             csv_path = csv,
    #             model_name = model_name,
    #             batch_size =  24,
    #             docker_image = "pytorch:latest"
    #     }
    # }
    output {
        # Array[File] embeddings = ESM2EmbeddingsTask.embeddings
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
        String output_dir = "/home/scripts"
    }
    command <<<
        set -euxo pipefail
        printenv
        # mkdir output
        /opt/venv/bin/python /home/scripts/split_fasta.py ~{fasta_path} --max_records_per_partition=~{max_records_per_partition} --output_dir=~{output_dir} --save_csv
        ls
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        cpu: cpu
    }
    output {
        # Array[File] csvs=glob("/home/scripts/output/*.csv")
        File csv = "x000.csv"
    }
}

task ESM2EmbeddingsTask {
    input {
        File csv_path
        File model_parameters = "s3://167428594774-us-east-1-aho/models/esm/esm2_t36_3B_UR50D.tar"
        String memory = "32 GiB"
        Int cpu = 4
        String docker_image = "pytorch"
        String model_name = "facebook/esm2_t36_3B_UR50D"
        Int batch_size = 24
        String output_dir = "/home/scripts"
    }
    command <<<
        set -euxo pipefail
        printenv
        mkdir output
        /opt/venv/bin/python /home/scripts/generate_esm2_embeddings.py ~{csv_path} --model_name=~{model_name} --output_file=~{output_dir}/embeddings.npy
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

