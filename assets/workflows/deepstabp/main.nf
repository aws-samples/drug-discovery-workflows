nextflow.enable.dsl = 2

workflow DeepSTABp {
    take:
    input_fasta
    model_weights
    growth_temp
    measurement_type

    main:
    prediction = PredictProteinStability(
        Channel.fromPath(input_fasta),
        Channel.fromPath(model_weights),
        growth_temp,
        measurement_type
    )

    emit:
    prediction
}

process PredictProteinStability {
    tag "${input_fasta}"
    label "deepstabp"

    // omics.r.xlarge
    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 32.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path input_fasta
        path model_weights
        val growth_temp
        val measurement_type

    output:
        path "deepstabp_prediction.csv", emit: prediction

    script:
    """
    set -euxo pipefail

    export HF_HOME=.

    mkdir -p Rostlab
    cp -R ${model_weights} Rostlab/

    ls -lah .
    tree .

    python /opt/deepstabp/workflows/prediction_model/predict_cuda.py ${input_fasta} \
        --growth_temp ${growth_temp} \
        --measurement_type ${measurement_type} \
        --save ./

    ls -lah .
    tree .
    """
}


workflow  {
    DeepSTABp(
        params.input_fasta,
        params.model_weights,
        params.growth_temp,
        params.measurement_type
    )
}
