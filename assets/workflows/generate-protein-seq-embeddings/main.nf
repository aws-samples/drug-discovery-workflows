#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow GenerateEmbeddings {
    Channel
        .fromPath(params.fasta_path)
        .splitFasta(
            by: params.max_records_per_partition,
            file: true
            )
        .set { fasta_ch }

    fasta_ch.view(part -> "Created FASTA partition $part ")
    GenerateEmbeddingsTask(fasta_ch, file(params.model_parameters))

    GenerateEmbeddingsTask.out.embeddings.collect().set { embeddings_ch }

    emit:
    embeddings = embeddings_ch
}

process GenerateEmbeddingsTask {
    label 'generate_embeddings'
    cpus 8
    memory '32 GB'
    maxRetries 2
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
    path fasta_file
    path model_parameters

    output:
    path 'output/embeddings.npy', emit: embeddings

    script:
    """
    set -euxo pipefail
    mkdir model output
    tar -xvf $model_parameters -C model
    /opt/conda/bin/python /home/scripts/generate_protein_seq_embeddings.py $fasta_file \
        --output_file=output/embeddings.npy \
        --pretrained_model_name_or_path model
    """
}

workflow {
    GenerateEmbeddings()
}
