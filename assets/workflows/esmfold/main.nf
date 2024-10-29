#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow ESMFold {
    take:
    fasta_path
    esmfold_max_records_per_partition
    esmfold_model_parameters

    main:
    fasta_path.view()
    ESMFoldTask(fasta_path, esmfold_model_parameters)
    ESMFoldTask.out.pdb.set { pdb }
    ESMFoldTask.out.metrics.set { metrics }
    ESMFoldTask.out.tensors.set { tensors }
    ESMFoldTask.out.pae_plot.set { pae_plot }
    ESMFoldTask.out.combined_metrics.set { combined_metrics }

    emit:
    pdb
    metrics
    tensors
    pae_plot
    combined_metrics
}

process ESMFoldTask {
    label 'esmfold'
    cpus 8
    memory '30 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${task.process.replace(':', '/')}/${task.index}"

    input:
    path fasta_path
    path esmfold_model_parameters

    output:
    path 'output/*/*.pdb', emit: pdb
    path 'output/*/*.json', emit: metrics
    path 'output/*/*.pt', emit: tensors
    path 'output/*/*.png', emit: pae_plot
    path 'combined_metrics.jsonl', emit: combined_metrics

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/conda/bin/python /home/scripts/esmfold_inference.py $fasta_path \
        --output_dir "output" \
        --pretrained_model_name_or_path $esmfold_model_parameters
    cat output/*/*.json >> combined_metrics.jsonl
    """
}

workflow {
    ESMFold(
        Channel.fromPath(params.fasta_path),
        Channel.value(params.esmfold_max_records_per_partition),
        Channel.fromPath(params.esmfold_model_parameters)
    )
}
