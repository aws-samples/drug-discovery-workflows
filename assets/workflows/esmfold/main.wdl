version 1.0

workflow ESMFoldFlow {
    input {
        File fasta_path
        Int max_records_per_partition = 1
        File model_parameters = "s3://{{S3_BUCKET_NAME}}/ref-data/esmfold/facebook/esmfold_v1/model.tar"
    }

    call ShardFastaTask{
        input:
            fasta_path = fasta_path,
            max_records_per_partition = max_records_per_partition,
            docker_image = "{{biolambda:latest}}",
    }
    scatter (csv in ShardFastaTask.csvs){
        call ESMFoldTask{
            input:
                csv_path = csv,
                model_parameters = model_parameters,
                docker_image = "{{esm2:latest}}"
        }
    }
    output {
        Array[File] pdb = ESMFoldTask.pdb
        Array[File] metrics = ESMFoldTask.metrics
        Array[File] pae = ESMFoldTask.pae
        Array[File] outputs = ESMFoldTask.outputs
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

task ESMFoldTask {
    input {
        File csv_path
        File model_parameters
        String memory = "16 GiB"
        Int cpu = 8
        String docker_image = "{{esmfold}}"
    }
    command <<<
        set -euxo pipefail
        mkdir $(pwd)/model
        tar -xvf ~{model_parameters} -C $(pwd)/model
        /opt/conda/bin/python /home/scripts/esmfold_inference.py ~{csv_path} \
        --output_dir $(pwd) --pretrained_model_name_or_path $(pwd)/model
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        acceleratorCount: 1,
        acceleratorType: "nvidia-tesla-t4-a10g",
        cpu: cpu
        }
    output {
        File pdb = "prediction.pdb"
        File metrics = "metrics.json"
        File pae = "pae.png"
        File outputs = "outputs.pt"
    }
}
