process RoseTTAFold2Predict {
    tag "${pdbdir}"
    label "rfantibody"

    // omics.c.4xlarge
    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path pdbdir
        val model_weights

    output:
        path "outputs/"

    script:
    """
    set -euxo pipefail

    ls -lah .
    tree .

    mkdir -p /home/weights

    cp -R ${model_weights.join(' ')} /home/weights

    mkdir -p outputs

    INPUT_PDB=\$(realpath ${pdbdir})
    OUTPUT_PDB=\$(realpath outputs)

    pushd /home

    poetry run python /home/scripts/rf2_predict.py \
        model.model_weights=/home/weights/RF2_ab.pt \
        input.pdb_dir=\$INPUT_PDB \
        output.pdb_dir=\$OUTPUT_PDB

    popd

    ls -lah .
    tree .
    """
}

workflow RoseTTAFold2 {
    take:
        pdbdir
        model_weights

    main:
        predictions = RoseTTAFold2Predict(
            Channel.fromPath(pdbdir),
            Channel.fromPath(model_weights).collect()
        )

    emit:
        predictions
}
