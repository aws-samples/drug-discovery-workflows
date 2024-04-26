version 1.0

workflow ESMFoldFlow {
    input {
        File fasta_path
        Int max_records_per_partition = 24
        String model_parameters = "s3://aws-hcls-ml/public_assets_support_materials/guidance-for-protein-folding/compressed/esmfold_transformers_params.tar"
    }

    call ShardFastaTask{
        input:
            fasta_path = fasta_path,
            max_records_per_partition = max_records_per_partition,
            docker_image = "biolambda:latest",
    }
    scatter (csv in ShardFastaTask.csvs){
        call ESMFoldTask{
            input:
                csv_path = csv,
                model_parameters = model_parameters,
                docker_image = "transformers:latest"
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
        String docker_image = "biolambda:latest"
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
        String memory = "32 GiB"
        Int cpu = 4
        String docker_image = "esmfold"
        String output_dir = "output"    
    }
    command <<<
        # export TMPDIR="/tmp"
        tar -xvf ~{model_parameters} -C $TMPDIR
        /opt/conda/bin/python /home/scripts/esmfold_inference.py -i ~{csv_path} -o ~{output_dir} -m $TMPDIR
    >>>
    runtime {
        docker: docker_image,
        memory: memory,
        acceleratorCount: 1,
        acceleratorType: "nvidia-tesla-t4-a10g",
        cpu: cpu
        }
    output {
        File pdb = "~{output_dir}/prediction.pdb"
        File metrics = "~{output_dir}/metrics.json"
        File pae = "~{output_dir}/pae.png"
        File outputs = "~{output_dir}/outputs.pt"
    }
}

