nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    //Convert to files
    if (params.smi_input_path[-1] == "/") {
        smi_input_path = params.smi_input_path + "*"
    } else {
        smi_input_path = params.smi_input_path
    }

    if (params.fasta_path[-1] == "/") {
        fasta_path = params.fasta_path + "*"
    } else {
        fasta_path = params.fasta_path
    }

    smiles = Channel.fromPath(smi_input_path)
        .collectFile(name: 'smi_input.json')

    RunMolMIMGenerate(
        params.molmim_script,
        params.molmim_model,
        smiles
    )

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

    num_poses = 3
    RunDiffdock(
        params.diffdock_script,
        params.diffdock_model,
        RunMolMIMGenerate.out.sdfs,
        RunAlphaFold2.out.pdfs,
        num_poses
    )
}

process RunMolMIMGenerate {
    label 'molmim'
    cpus 8
    memory "32 GB"
    accelerator 1, type: "nvidia-tesla-a10g"
    publishDir "/mnt/workflow/pubdir/"

    input:
        path molmim_script
        path model
        path smiles

    output:
        path "*.sdf", emit: sdfs
    script:
    """
    set -ex

    export CUDA_VISIBLE_DEVICES=0
    export NIM_CACHE_PATH=${model}

    for s in `cat ${smiles}`
    do
        echo \$s

        python ${molmim_script} ${smiles} .
        sleep 1
    done

    sleep 60
    """
}


process RunAlphaFold2 {
    errorStrategy 'retry'
    label 'alphafold2'
    cpus { 2 * Math.pow(2, task.attempt+2) }
    memory { 8.GB * Math.pow(2, task.attempt+2) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries 1
    publishDir "/mnt/workflow/pubdir/"

    input:
        path model_parameters
        path executable
        path sequences

    output:
        path "*.pdb", emit: pdfs
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
    sleep 10
    """
}


process RunDiffdock {
    label 'diffdock'
    cpus 8
    memory "32 GB"
    accelerator 1, type: "nvidia-tesla-a10g"
    publishDir "/mnt/workflow/pubdir/"

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
    sleep 300
    for pro in ${protein_file}
    do
        for lig in ${ligand_file}
        do
            /usr/bin/python3 ${executable} \$pro \$lig ${num_poses}
            sleep 10
        done
    done
    echo "shutting down TritonServe"
    kill \$Triton_PID
    sleep 5
    """
}

