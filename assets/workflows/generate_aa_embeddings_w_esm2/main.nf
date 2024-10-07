#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.fasta_path
params.max_records_per_partition = 8
params.model_parameters = 's3://{{S3_BUCKET_NAME}}/ref-data/esm2/facebook/esm2_t33_650M_UR50D/model.tar'

workflow {
    fasta_ch = Channel.fromPath(params.fasta_path)

    ShardFastaTask(fasta_ch, params.max_records_per_partition)
    ESM2EmbeddingsTask(ShardFastaTask.out.csvs.flatten(), file(params.model_parameters))

    ESM2EmbeddingsTask.out.embeddings.collect().set { embeddings_ch }

    emit:
    embeddings = embeddings_ch
}

process ShardFastaTask {
    container '{{protein-utils:latest}}'
    cpus 2
    memory '4 GB'

    input:
    path fasta_path
    val max_records_per_partition

    output:
    path '*.csv', emit: csvs

    script:
    """
    set -euxo pipefail
    /opt/venv/bin/python /home/putils/src/putils/split_fasta.py $fasta_path \
        --max_records_per_partition=$max_records_per_partition \
        --save_csv
    """
}

process ESM2EmbeddingsTask {
    container '{{esm2:latest}}'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    input:
    path csv_path
    path model_parameters

    output:
    path 'embeddings.npy', emit: embeddings

    script:
    """
    set -euxo pipefail
    mkdir model
    tar -xvf $model_parameters -C model
    /opt/conda/bin/python /home/scripts/generate_esm2_embeddings.py $csv_path \
        --output_file=embeddings.npy \
        --pretrained_model_name_or_path model
    """
}
