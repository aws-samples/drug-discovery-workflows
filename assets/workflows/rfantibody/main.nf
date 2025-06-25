nextflow.enable.dsl = 2

include { RoseTTAFold2Predict } from './rf2'
include { ProteinmpnnInterfaceDesign } from './proteinmpnn'
include { RFdiffusionInference } from './rfdiffusion'

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

    design_out = RFdiffusionInference(
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

    rf2_out = RoseTTAFold2Predict(
        output_pdb,
        model_weights
    )

    emit:
    design_out
    output_pdb
    rf2_out
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
