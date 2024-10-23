#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.fasta_path
params.max_records_per_partition = 8

workflow {
    Channel
        .fromPath(params.fasta_path)
        .splitFasta(
            by: params.max_records_per_partition,
            file: true
            )
        .set { fasta_ch }

    fasta_ch.view(part -> "Created FASTA partition $part ")
    ESM2EmbeddingsTask(fasta_ch file(params.model_parameters))

    ESM2EmbeddingsTask.out.embeddings.collect().set { embeddings_ch }

    emit:
    embeddings = embeddings_ch
}

process ESM2EmbeddingsTask {
    label 'esm2'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    input:
    path fasta_file
    path model_parameters

    output:
    path 'embeddings.npy', emit: embeddings

    script:
    """
    set -euxo pipefail
    mkdir model
    tar -xvf $model_parameters -C model
    /opt/conda/bin/python /home/scripts/generate_esm2_embeddings.py $fasta_file \
        --output_file=embeddings.npy \
        --pretrained_model_name_or_path model
    """
}
