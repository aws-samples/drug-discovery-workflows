nextflow.enable.dsl = 2

workflow EfficientEvolution {
    take:
    params

    main:
    out = Recommend(
        Channel.fromPath(params.sequence_fasta),
        Channel.fromPath(params.model_weights).collect(),
        params.model_names,
        params.alpha ? params.alpha : ""
    )

    emit:
    recommendation = out
}

process Recommend {
    label "efficientevolution"

    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path sequence_fasta
        val model_weights
        val model_names
        val alpha
    output:
        path "recommendation.csv"

    script:
    def alpha_param = alpha ? "--alpha ${alpha}" : ""

    """
    set -euxo pipefail

    mkdir -p /root/.cache/torch/hub/checkpoints

    cp ${model_weights.join(' ')} /root/.cache/torch/hub/checkpoints/
    
    sequence_contents=\$(cat ${sequence_fasta})

    export CUDA_VISIBLE_DEVICES=0

    python /opt/efficient-evolution/bin/recommend.py \
        "\${sequence_contents}" \
        --model-names ${model_names.join(' ')} \
        ${alpha_param} \
        > recommendation.csv

    """
}

workflow  {
    EfficientEvolution(params)
}
