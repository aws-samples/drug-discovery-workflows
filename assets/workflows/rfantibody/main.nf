nextflow.enable.dsl = 2

workflow RFantibody {
    take:
    params

    main:
    model_weights = Channel.fromPath(params.model_weights).collect()

    converted_pdb = Channel.empty()

    if (params.is_hlt == false) {
        converted_pdb = ConvertPdbToHlt(
            Channel.fromPath(params.framework_pdb),
            params.heavy_chain_id,
            params.light_chain_id,
            params.target_chains ?: ""
        )
    } else {
        converted_pdb = Channel.fromPath(params.framework_pdb)
    }

    design_out = RunRFdiffusionInference(
        Channel.fromPath(params.target_pdb),
        converted_pdb,
        params.hotspot_res,
        params.design_loops,
        params.num_designs,
        model_weights
    )

    output_pdb = ProteinmpnnInterfaceDesign(
        design_out,
        model_weights
    )

    emit:
    design_out
    output_pdb
}

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

process RunRFdiffusionInference {
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

process ConvertPdbToHlt {
    tag "${input_pdb}"
    label "rfantibody"

    // omics.c.4xlarge
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path input_pdb
        val heavy_chain_id
        val light_chain_id
        val target_chains

    output:
        path "${input_pdb.getBaseName()}_hlt.pdb"

    script:
    def target_arg = target_chains ? "--target ${target_chains}" : ""

    """
    set -euxo pipefail

    ls -lah .
    tree .

    INPUT_PDB=\$(realpath ${input_pdb})
    OUTPUT_PDB=\$(pwd)/${input_pdb.getBaseName()}_hlt.pdb

    pushd /home

    poetry run python /home/scripts/util/chothia2HLT.py \
        \$INPUT_PDB \
        --heavy ${heavy_chain_id}  \
        --light ${light_chain_id} \
        ${target_arg} \
        --output \$OUTPUT_PDB

    popd

    ls -lah .
    tree .
    """
}

workflow  {
    RFantibody(params)
}
