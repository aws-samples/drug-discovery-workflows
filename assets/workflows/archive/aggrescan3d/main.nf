nextflow.enable.dsl = 2

workflow Aggrescan3D {
    take:
    params

    main:
    input_pdb = Channel.fromPath(params.input_pdb)

    // Ensure chain has a default value (empty string if not provided)
    chain = params.chain ?: ""

    // Predict Aggregation
    aggregation_out = PredictAggregation(input_pdb, chain, params.distance)

    // Predict Aggregation Dynamic
    // Error for Dynamic mode, modeler dep of CABSFlex requires license​
    // aggregation_dynamic_out = PredictAggregationDynamic(input_pdb)

    emit:
    aggregation_out
    // aggregation_dynamic_out
}


process PredictAggregation {
    tag "${input_pdb}"
    label "aggrescan3d"

    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path input_pdb
        val chain
        val distance

    output:
        path "output/"

    script:
    // Chain arg should be empty string if not provided
    def chain_arg = chain ? "-C ${chain}" : ""

    """
    set -euxo pipefail

    ls -lah

    input_realpath=\$(realpath ${input_pdb})

    mkdir -p output
    pushd output

    aggrescan \
        -i \$input_realpath \
        -D ${distance} \
        ${chain_arg} \
        -v 4

    popd

    ls -lah
    ls -lah output
    tree .
    """
}

process PredictAggregationDynamic {
    tag "${input_pdb}"
    label "aggrescan3d"

    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path input_pdb
    output:
        path "output/"

    script:
    """
    set -euxo pipefail

    ls -lah

    input_realpath=\$(realpath ${input_pdb})

    mkdir -p output
    pushd output

    aggrescan \
        -i \$input_realpath \
        --dynamic

    popd

    ls -lah
    ls -lah output
    tree .
    """
}


workflow  {
    Aggrescan3D(params)
}
