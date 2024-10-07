version 1.0

workflow ESM2EmbeddingsFlow {
    input {
        File fasta_path
        Int max_records_per_partition = 24
        String pretrained_model_uri = "s3://167428594774-us-east-1-aho/models/esm/esm2_t6_8M_UR50D.tar"
    }

    call ShardFastaTask{
        input:
            fasta_path = fasta_path,
            max_records_per_partition = max_records_per_partition,
            docker_image = "{{biolambda:latest}}",
    }
    scatter (csv in ShardFastaTask.csvs){
        call ESM2EmbeddingsTask{
            input:
                csv_path = csv,
                pretrained_model_uri = pretrained_model_uri,
                batch_size =  24,
                docker_image = "{{esm2:latest}}"
        }
    }
    output {
        Array[File] embeddings = ESM2EmbeddingsTask.embeddings
    } 
}

task ShardFastaTask {
    input {
        File fasta_path
        Int cpu = 2
        String memory = "4 GiB"        
        String docker_image = "{{biolambda:latest}}"
        Int max_records_per_partition = 24
    }
    command <<<
        set -euxo pipefail
        /opt/venv/bin/python /home/scripts/split_fasta.py ~{fasta_path} \
        --max_records_per_partition=~{max_records_per_partition} \
        --save_csv
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        cpu: cpu
    }
    output {
        Array[File] csvs=glob("*.csv")
    }
}

task ESM2EmbeddingsTask {
    input {
        File csv_path
        File pretrained_model_uri = "s3://167428594774-us-east-1-aho/models/esm/esm2_t36_3B_UR50D.tar"
        String memory = "32 GiB"
        Int cpu = 4
        String docker_image = "{{esm2:latest}}"
        Int batch_size = 24
    }
    command <<<
        set -euxo pipefail
        tar -xvf ~{pretrained_model_uri} .
        /opt/conda/bin/python /home/scripts/generate_esm2_embeddings.py ~{csv_path} \
        --pretrained_model_name_or_path="." --output_file=embeddings.npy
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        acceleratorCount: 1,
        acceleratorType: "nvidia-tesla-t4-a10g",
        cpu: cpu        
    }
    output {
        File embeddings = "embeddings.npy"
    }
}

