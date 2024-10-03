#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.fasta_path
params.max_records_per_partition = 1
params.model_parameters = 's3://{{S3_BUCKET_NAME}}/ref-data/esmfold/facebook/esmfold_v1/model.tar'

workflow {
    fasta_ch = Channel.fromPath(params.fasta_path)

    ShardFastaTask(fasta_ch, params.max_records_per_partition)
    ESMFoldTask(ShardFastaTask.out.csvs.flatten(), file(params.model_parameters))

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

process ESMFoldTask {
    container '{{esm2:latest}}'
    cpus 8
    memory '16 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    input:
    path csv_path
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
    /opt/conda/bin/python /home/scripts/esmfold_inference.py $csv_path \
        --output_dir . \
        --pretrained_model_name_or_path model
    """
}
