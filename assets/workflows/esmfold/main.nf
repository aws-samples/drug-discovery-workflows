#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow ESMFold {
    Channel
        .fromPath(params.fasta_path)
        .splitFasta(
            by: params.max_records_per_partition,
            file: true
            )
        .set { fasta_ch }

    fasta_ch.view(part -> "Created FASTA partition $part ")
    ESMFoldTask(fasta_ch, file(params.model_parameters))
    ESMFoldTask.out.output.collect().set { output_ch }

    emit:
    output = output_ch
}

process ESMFoldTask {
    label 'esmfold'

    input:
    path fasta_file
    path model_parameters

    output:
    path 'output/', emit: output

    script:
    """
    set -euxo pipefail
    mkdir model output
    tar -xvf $model_parameters -C model
    /opt/conda/bin/python /home/scripts/esmfold_inference.py $fasta_file \
        --output_dir output \
        --pretrained_model_name_or_path model
    """
}

workflow {
    ESMFold()
}
