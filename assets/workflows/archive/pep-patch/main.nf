nextflow.enable.dsl = 2

workflow PEPPatch {
    take:
        params

    main:
    if (params.mode == "both") {
        ComputeElectrostatic(
            Channel.fromPath(params.electrostatic_parm),
            Channel.fromPath(params.electrostatic_crd),
            params.probe_radius,
            params.patch_cutoff,
            params.integral_cutoff,
            params.surface_type,
            params.pos_patch_cmap,
            params.neg_patch_cmap,
            params.electrostatic_ply_cmap,
            params.n_patches,
            params.size_cutoff,
            params.gauss_shift,
            params.gauss_scale,
            params.check_cdrs,
            params.ply_clim
        )
        AssignHydrophobicity(
            Channel.fromPath(params.hydrophobicity_parm),
            Channel.fromPath(params.hydrophobicity_crd),
            params.scale,
            params.smiles,
            params.stride,
            params.surftype,
            params.group_heavy,
            params.surfscore,
            params.sap,
            params.blur_rad,
            params.sh,
            params.sh_rad,
            params.potential,
            params.rmax,
            params.solv_rad,
            params.grid_spacing,
            params.rcut,
            params.alpha,
            params.blur_sigma,
            params.patches,
            params.patch_min,
            params.hydrophobic_ply_cmap
        )
    } else if (params.mode == "electrostatic") {
        ComputeElectrostatic(
            Channel.fromPath(params.electrostatic_parm),
            Channel.fromPath(params.electrostatic_crd),
            params.probe_radius,
            params.patch_cutoff,
            params.integral_cutoff,
            params.surface_type,
            params.pos_patch_cmap,
            params.neg_patch_cmap,
            params.electrostatic_ply_cmap,
            params.n_patches,
            params.size_cutoff,
            params.gauss_shift,
            params.gauss_scale,
            params.check_cdrs,
            params.ply_clim
        )
    } else if (params.mode == "hydrophobicity") {
        AssignHydrophobicity(
            Channel.fromPath(params.hydrophobicity_parm),
            Channel.fromPath(params.hydrophobicity_crd),
            params.scale,
            params.smiles,
            params.stride,
            params.surftype,
            params.group_heavy,
            params.surfscore,
            params.sap,
            params.blur_rad,
            params.sh,
            params.sh_rad,
            params.potential,
            params.rmax,
            params.solv_rad,
            params.grid_spacing,
            params.rcut,
            params.alpha,
            params.blur_sigma,
            params.patches,
            params.patch_min,
            params.hydrophobic_ply_cmap
        )
    } else {
        error "Invalid mode: ${params.mode}"
    }
}

process AssignHydrophobicity {
    tag "${hydrophobicity_parm.baseName}/${hydrophobicity_crd.baseName}"
    label "peppatch"

    // omics.c.4xlarge
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path hydrophobicity_parm
        path hydrophobicity_crd
        val scale
        val smiles
        val stride
        val surftype
        val group_heavy
        val surfscore
        val sap
        val blur_rad
        val sh
        val sh_rad
        val potential
        val rmax
        val solv_rad
        val grid_spacing
        val rcut
        val alpha
        val blur_sigma
        val patches
        val patch_min
        val hydrophobic_ply_cmap

    // Using single directory for all outputs
    // could also use optional outputs
    output:
        path "pep_patch_hydrophobic_out/", emit: out

    script:

    // Ensure that the paths are quoted correctly in bash
    def quoteEscape = { param -> param.toString().replaceAll('\'', '\\\'') } 
    def quoteParam = { param -> "'${quoteEscape(param)}'" }

    def smiles_param = smiles ? "--smiles ${quoteParam(smiles)}" : ""
    def group_heavy_param = group_heavy ? "--group_heavy" : ""
    def surfscore_param = surfscore ? "--surfscore" : ""
    def sap_param = sap ? "--sap" : ""
    def sh_param = sh ? "--sh" : ""
    def potential_param = potential ? "--potential" : ""
    def patches_param = patches ? "--patches" : ""

    """
    set -euxo pipefail

    tree .

    abs_param=\$(realpath ${hydrophobicity_parm})
    crd_param=\$(realpath ${hydrophobicity_crd})

    mkdir -p pep_patch_hydrophobic_out
    pushd pep_patch_hydrophobic_out

    pep_patch_hydrophobic \
        \${abs_param} \
        \${crd_param} \
        --scale ${scale} \
        ${smiles_param} \
        --out out.npz \
        --stride ${stride} \
        --surftype ${surftype} \
        ${group_heavy_param} \
        ${surfscore_param} \
        ${sap_param} \
        --blur_rad ${blur_rad} \
        ${sh_param} \
        --sh_rad ${sh_rad} \
        ${potential_param} \
        --rmax ${rmax} \
        --solv_rad ${solv_rad} \
        --grid_spacing ${grid_spacing} \
        --rcut ${rcut} \
        --alpha ${alpha} \
        --blur_sigma ${blur_sigma} \
        --ply_cmap ${hydrophobic_ply_cmap} \
        ${patches_param} \
        --patch_min ${patch_min} \
        --verbose \
        --ply_out out.ply

    popd

    ls -lah pep_patch_hydrophobic_out
    tree .
    """
}

process ComputeElectrostatic {
    tag "${electrostatic_parm.baseName}/${electrostatic_crd.baseName}"
    label "peppatch"

    // omics.c.4xlarge
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path electrostatic_parm
        path electrostatic_crd
        val probe_radius
        val patch_cutoff
        val integral_cutoff
        val surface_type
        val pos_patch_cmap
        val neg_patch_cmap
        val electrostatic_ply_cmap
        val n_patches
        val size_cutoff
        val gauss_shift
        val gauss_scale
        val check_cdrs
        val ply_clim

    // Using single directory for all outputs
    // could also use optional outputs
    output:
        path "pep_patch_electrostatic_out/", emit: out

    script:
    def check_cdrs_param = check_cdrs ? "--check_cdrs" : ""
    def ply_clim_param = ply_clim ? "--ply_clim ${ply_clim.join(' ')}" : ""

    """
    set -euxo pipefail

    tree .

    abs_param=\$(realpath ${electrostatic_parm})
    crd_param=\$(realpath ${electrostatic_crd})

    mkdir -p pep_patch_electrostatic_out
    pushd pep_patch_electrostatic_out

    pep_patch_electrostatic \
        \${abs_param} \
        \${crd_param} \
        --apbs_dir apbs \
        --probe_radius ${probe_radius} \
        --patch_cutoff ${patch_cutoff.join(' ')} \
        --integral_cutoff ${integral_cutoff.join(' ')} \
        --surface_type ${surface_type} \
        --ply_out potential \
        --pos_patch_cmap ${pos_patch_cmap} \
        --neg_patch_cmap ${neg_patch_cmap} \
        --ply_cmap ${electrostatic_ply_cmap} \
        ${ply_clim_param} \
        ${check_cdrs_param} \
        --n_patches ${n_patches} \
        --size_cutoff ${size_cutoff} \
        --gauss_shift ${gauss_shift} \
        --gauss_scale ${gauss_scale} \
        -o patches.csv

    popd

    ls -lah pep_patch_electrostatic_out
    tree .
    """
}

workflow  {
    PEPPatch(params)
}
