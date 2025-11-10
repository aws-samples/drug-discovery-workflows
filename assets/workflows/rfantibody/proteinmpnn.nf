process ProteinmpnnInterfaceDesign {
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
        path "proteinmpnn_output_pdb/", emit: proteinmpnn_output_pdb

    script:
    """
    set -euxo pipefail

    ls -lah .
    ls -lah ${pdbdir}
    tree .
    
    mkdir -p /home/weights

    cp -R ${model_weights.join(' ')} /home/weights
    mkdir -p proteinmpnn_output_pdb

    pdbdir_abs=\$(realpath ${pdbdir})
    output_prefix_abs=\$(realpath proteinmpnn_output_pdb)

    pushd /home

    poetry run python /home/scripts/proteinmpnn_interface_design.py \
        -pdbdir \$pdbdir_abs \
        -outpdbdir \$output_prefix_abs 

    popd

    ls -lah .
    ls -lah proteinmpnn_output_pdb
    tree .
    """
}

workflow Proteinmpnn {
    take:
        pdbdir
        model_weights

    main:
        design_out = ProteinmpnnInterfaceDesign(
            Channel.fromPath(pdbdir),
            Channel.fromPath(model_weights).collect()
        )

    emit:
        design_out
}
