version 1.0

workflow ESM2EmbeddingsFlow {
    input {
        File fasta_path
        String model_name = "facebook/esm2_t36_3B_UR50D"
    }

    call ShardFastaTask{
        input:
            fasta_path = fasta_path,
            docker_image = "{{biolambda:latest}}",
    }
    call ESM2EmbeddingsTask{
        input:
            fasta_path = ValidateInputsTask.fasta,
            model_name = model_name,
            docker_image = "{{pytorch:latest}}"
    }
    output {
        File embeddings = ESM2EmbeddingsTask.embeddings
    } 
}

# task ValidateInputsTask {
#     input {
#         File fasta_path
#         Int cpu = 2
#         String memory = "4 GiB"        
#         String docker_image = "protein-utils"
#         Int max_seq = 1
#         Int max_length = 800
#         String output_file = "input.fasta"
#     }
#     command <<<
#         set -euxo pipefail
#         printenv
#         /opt/venv/bin/python /opt/venv/lib/python3.8/site-packages/putils/validate_inputs.py ~{fasta_path} --max_seq=~{max_seq} --max_length=~{max_length} --output_file=~{output_file}
#     >>>
#     runtime {
#         docker: docker_image,
#         memory: memory,
#         cpu: cpu
#     }
#     output {
#         Map[String, String] seq_info = read_json("seq_info.json")
#         File fasta = "~{output_file}"
#     }
# }

# task ESMFoldTask {
#     input {
#         File fasta_path
#         File model_parameters = "ref_data/esmfold_parameters_221230.tar"
#         String memory = "32 GiB"
#         Int cpu = 4
#         String docker_image = "esmfold"
#         String chunk_size = "128"    
#         String output_dir = "output"    
#     }
#     command <<<
#         tar -xvf ~{model_parameters} -C $TMPDIR
#         /opt/venv/bin/python /opt/esm/scripts/esmfold_inference.py -i ~{fasta_path} -o ~{output_dir} -m $TMPDIR --chunk-size ~{chunk_size} --cpu-only
#     >>>
#     runtime {
#         docker: docker_image,
#         memory: memory,
#         acceleratorCount: 1,
#         acceleratorType: "nvidia-tesla-t4-a10g",
#         cpu: cpu        
#     }
#     output {
#         File pdb = "~{output_dir}/prediction.pdb"
#         File metrics = "~{output_dir}/metrics.json"
#         File pae = "~{output_dir}/pae.png"
#         File outputs = "~{output_dir}/outputs.pt"
#     }
# }

