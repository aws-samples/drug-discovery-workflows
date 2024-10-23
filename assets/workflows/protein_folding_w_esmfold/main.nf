#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.fasta_path
params.max_records_per_partition = 1

workflow {
    Channel
        .fromPath(params.fasta_path)
        .splitFasta(
            by: params.max_records_per_partition,
            file: true
            )
        .set { fasta_ch }

    fasta_ch.view(part -> "Created FASTA partition $part ")
    ESMFoldTask(fasta_ch, file(params.model_parameters))

    ESMFoldTask.out.pdb.collect().set { pdb_ch }
    ESMFoldTask.out.metrics.collect().set { metrics_ch }
    ESMFoldTask.out.pae.collect().set { pae_ch }
    ESMFoldTask.out.outputs.collect().set { outputs_ch }

    emit:
    pdb = pdb_ch
    metrics = metrics_ch
    pae = pae_ch
    outputs = outputs_ch
}

process ESMFoldTask {
    label 'esm2'
    cpus 8
    memory '24 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    input:
    path fasta_file
    path model_parameters

    output:
    path 'prediction.pdb', emit: pdb
    path 'metrics.json', emit: metrics
    path 'pae.png', emit: pae
    path 'outputs.pt', emit: outputs

    script:
    """
    set -euxo pipefail
    mkdir model
    tar -xvf $model_parameters -C model
    /opt/conda/bin/python /home/scripts/esmfold_inference.py $fasta_file \
        --output_dir . \
        --pretrained_model_name_or_path model
    """
}
