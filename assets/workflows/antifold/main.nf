nextflow.enable.dsl = 2

workflow AntiFold {

    take:
        pdb_file
        heavy_chain
        light_chain
        antigen_chain
        nanobody_chain
        pdbs_csv
        pdb_dir

    main:
    heavy_chain ?: 'H'
    light_chain ?: 'L' 
    if (!antigen_chain && !nanobody_chain) {
        if (pdb_file) { 
            println("Running AntiFold on single PDB (or CIF) file with specified heavy chain and light chain")
            AntiFoldSinglePDBHLChain(pdb_file, heavy_chain, light_chain)
        }
        else if (pdb_dir) {
            println("Running AntiFold on multiple PDB files in `pdb_dir` with specified chains in `pdbs_csv`")
            AntiFoldMultiplePDB(pdb_dir, pdbs_csv)
        }
        else {
            error "Error: provide a single PDB file or a directory containing multiple PDB files to run AntiFold!"
        }
    }
    else if (antigen_chain) {
        println("Running AntiFold on an antibody-antigen complex PDB file, with specified antigen chain")
        AntiFoldSinglePDBAntigenComplex(pdb_file, heavy_chain, light_chain, antigen_chain)
    }
    else if (nanobody_chain) {
        println("Running AntiFold on Nanobody or single-chain PDB file, with specified nanobody chain")
        AntiFoldSinglePDBNanobody(pdb_file, heavy_chain, light_chain, nanobody_chain)
    }
    else {
        error "Error: provide a single PDB file or a directory containing multiple PDB files to run AntiFold!\n--antigen_chain and --nanobody_chain param can only be used with single PDB input"
    }
}


process AntiFoldSinglePDBHLChain {
    label 'antifold'
    cpus 8
    memory '30 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path pdb_file
        val heavy_chain
        val light_chain
    output:
        path "antifold_out/*"

    script:
    """
    set -euxo pipefail
    mkdir antifold_output
    /opt/conda/envs/antifold/bin/python /AntiFold/antifold/main.py \
        --pdb_file  ${pdb_file}\
        --out_dir "antifold_out" \
        --heavy_chain ${heavy_chain} \
        --light_chain ${light_chain}
    """
}

process AntiFoldSinglePDBAntigenComplex {
    label 'antifold'
    cpus 8
    memory '30 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path pdb_file
        val heavy_chain
        val light_chain
        val antigen_chain
    output:
        path "antifold_out/*"

    script:
    """
    set -euxo pipefail
    mkdir antifold_output
    /opt/conda/envs/antifold/bin/python /AntiFold/antifold/main.py \
        --pdb_file  ${pdb_file}\
        --out_dir "antifold_out" \
        --heavy_chain ${heavy_chain} \
        --light_chain ${light_chain} \
        --antigen_chain ${antigen_chain}
    """
}

process AntiFoldSinglePDBNanobody {
    label 'antifold'
    cpus 8
    memory '30 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path pdb_file
        val heavy_chain
        val light_chain
        val nanobody_chain
    output:
        path "antifold_out/*"

    script:
    """
    set -euxo pipefail
    mkdir antifold_output
    /opt/conda/envs/antifold/bin/python /AntiFold/antifold/main.py \
        --pdb_file  ${pdb_file}\
        --out_dir "antifold_out" \
        --heavy_chain ${heavy_chain} \
        --light_chain ${light_chain} \
        --nanobody_chain ${nanobody_chain}
    """
}

process AntiFoldMultiplePDB {
    label 'antifold'
    cpus 8
    memory '30 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path pdb_file
        path pdbs_csv
    output:
        path "antifold_out/*"

    script:
    def csv_arg = pdbs_csv ? "--pdbs_csv ${pdbs_csv}" : ''
    """
    set -euxo pipefail
    mkdir antifold_output
    /opt/conda/envs/antifold/bin/python /AntiFold/antifold/main.py \
        --pdb_dir  ${pdb_dir}\
        --out_dir "antifold_out"\
        ${csv_arg}
    """
}


workflow {
    AntiFold(
        params.pdb_file,
        params.heavy_chain,
        params.light_chain,
        params.antigen_chain,
        params.nanobody_chain,
        params.pdbs_csv,
        params.pdb_dir
    )
}
