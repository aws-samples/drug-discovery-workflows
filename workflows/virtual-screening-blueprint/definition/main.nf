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
        .splitFasta(record: [id: true, seqString: true])
        .map { record -> "${record.id}zzzz${record.seqString}" }

    RunAlphaFold2(
        params.alphafold2_model,
        params.alphafold2_script,
        sequences
    )

    smiles = Channel.fromPath(smi_input_path)

    RunMolMIMGenerate(
        params.molmim_script,
        params.molmim_model,
        smiles,
        params.num_molecules
    )

    smiles_pdbs = RunMolMIMGenerate.out.smiles.combine(RunAlphaFold2.out.pdbs)

    RunDiffdock(
        params.diffdock_script,
        params.diffdock_model,
        smiles_pdbs,
        params.num_poses
    )
}

process RunAlphaFold2 {
    label 'alphafold2'
    errorStrategy 'retry'
    cpus { 2 * Math.pow(2, task.attempt) }
    memory { 8.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries params.max_retries
    publishDir "/mnt/workflow/pubdir/alphafold2/"

    input:
        path model_parameters
        path executable
        val sequences

    output:
        path "*.pdb", emit: pdbs
    script:
    """
    set -euxo pipefail

    cp /opt/*.py .
    export PYTHONPATH="${PYTHONPATH}:/opt/:./"
    export NIM_CACHE_PATH=${model_parameters}

    python ${executable} ${sequences}
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
        path "*.smi", emit: smiles
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
        val smiles_pdbs
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

    /usr/bin/python3 ${executable} ${smiles_pdbs[1]} ${smiles_pdbs[0]} ${num_poses}
    sleep 1
    echo "shutting down TritonServe"
    kill \$Triton_PID
    sleep 5
    """
}

