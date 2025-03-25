process RFdiffusionInference {
    tag "${target_pdb}, ${framework_pdb}"
    label "rfantibody"

    // omics.c.4xlarge
    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path target_pdb
        path framework_pdb
        val hotspot_res
        val design_loops
        val num_designs
        val model_weights

    output:
        path "rfdiff_output_designs/"

    script:
    """
    set -euxo pipefail

    ls -lah .
    tree .
    
    mkdir -p /home/weights

    cp -R ${model_weights.join(' ')} /home/weights
    mkdir -p rfdiff_output_designs

    target_pdb_abs=\$(realpath ${target_pdb})
    framework_pdb_abs=\$(realpath ${framework_pdb})
    output_prefix_abs=\$(realpath rfdiff_output_designs)/design

    pushd /home

    poetry run python  /home/scripts/rfdiffusion_inference.py \
        --config-path /home/src/rfantibody/rfdiffusion/config/inference \
        --config-name antibody \
        antibody.target_pdb=\$target_pdb_abs \
        antibody.framework_pdb=\$framework_pdb_abs \
        inference.ckpt_override_path=/home/weights/RFdiffusion_Ab.pt \
        'ppi.hotspot_res=${hotspot_res}' \
        'antibody.design_loops=${design_loops}' \
        inference.num_designs=${num_designs} \
        inference.output_prefix=\$output_prefix_abs

    popd

    ls -lah .
    ls -lah rfdiff_output_designs
    tree .
    """
}

workflow RFdiffusion {
    take:
        target_pdb
        framework_pdb
        hotspot_res
        design_loops
        num_designs
        model_weights
    
    main:
        designs = RFdiffusionInference(
            Channel.fromPath(target_pdb),
            Channel.fromPath(framework_pdb),
            hotspot_res,
            design_loops,
            num_designs,
            Channel.fromPath(model_weights).collect()
        )
    
    emit:
        designs
}
