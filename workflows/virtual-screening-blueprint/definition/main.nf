nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    //Convert to files
    if (params.fasta_path[-1] == "/") {
        fasta_path = params.fasta_path + "*"
    } else {
        fasta_path = params.fasta_path
    }

    if (params.smi_input_path[-1] == "/") {
        smi_input_path = params.smi_input_path + "*"
    } else {
        smi_input_path = params.smi_input_path
    }


    sequences = Channel.fromPath(fasta_path)
        .collectFile(name: 'temp.fasta')
        .splitFasta(record: [id: true, seqString: true])
        .map { record -> "${record.id}zzzz${record.seqString} " }
        .collectFile(name: 'combined_seqs.txt')

    RunAlphaFold2(
        params.alphafold2_model,
        params.alphafold2_script,
        sequences
    )

    smiles = Channel.fromPath(smi_input_path)
        .collectFile(name: 'smi_input.smi')

    RunMolMIMGenerate(
        params.molmim_script,
        params.molmim_model,
        smiles,
        params.num_molecules
    )

    RunDiffdock(
        params.diffdock_script,
        params.diffdock_model,
        RunMolMIMGenerate.out.sdfs,
        RunAlphaFold2.out.pdbs,
        params.num_poses
    )
}

process RunAlphaFold2 {
    label 'alphafold2'
    errorStrategy 'retry'
    cpus { 4 * Math.pow(2, task.attempt) }
    memory { 16.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries params.max_retries
    publishDir "/mnt/workflow/pubdir/alphafold2/"

    input:
        path model_parameters
        path executable
        path sequences

    output:
        path "*.pdb", emit: pdbs
    script:
    """
    set -euxo pipefail

    cp /opt/*.py .
    export PYTHONPATH="${PYTHONPATH}:/opt/:./"
    export NIM_CACHE_PATH=${model_parameters}
    for seq in `cat ${sequences}`
    do
        python ${executable} \$seq
    done
    """
}


process RunMolMIMGenerate {
    label 'molmim'
    errorStrategy 'retry'
    cpus { 2 * Math.pow(2, task.attempt) }
    memory { 8.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries params.max_retries
    publishDir "/mnt/workflow/pubdir/molmim/"

    input:
        path molmim_script
        path model
        path smiles
        val num_molecules

    output:
        path "*.sdf", emit: sdfs
    script:
    """
    set -ex

    export CUDA_VISIBLE_DEVICES=0
    export NIM_CACHE_PATH=${model}

    python ${molmim_script} ${smiles} ${num_molecules}
    """
}


process RunDiffdock {
    label 'diffdock'
    errorStrategy 'retry'
    cpus { 2 * Math.pow(2, task.attempt) }
    memory { 8.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries params.max_retries
    publishDir "/mnt/workflow/pubdir/diffdock/"

    input:
        path executable
        path model_parameters
        path ligand_file
        path protein_file
        val num_poses

    output:
        path "*.json", emit: dockingposes
    script:
    """
    set -ex

    cp /opt/*.py .
    export NIM_CACHE_PATH=${model_parameters}
    export PYTHONPATH="${PYTHONPATH}:/opt/./"
    /usr/local/lib/python3.10/dist-packages/nimlib/triton_start.sh -m ${model_parameters}/bionemo-diffdock_v1.2.0 -p 8080 -l 0 &
    Triton_PID=\$!
    sleep 120


    for pro in ${protein_file}
    do
        for lig in ${ligand_file}
        do
            /usr/bin/python3 ${executable} \$pro \$lig ${num_poses}
            sleep 1
        done
    done
    echo "shutting down TritonServe"
    kill \$Triton_PID
    sleep 5
    """
}

