nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    if (params.pdb_input_path[-1] == "/") {
        pdb_input_path = params.pdb_input_path + "*"
    } else {
        pdb_input_path = params.pdb_input_path
    }

    pdbs = Channel.fromPath(pdb_input_path)

    RunRFdiffusion(
        params.rfdiffusion_model,
        pdbs,
        params.contigs,
        params.num_design
    )

    RunProteinMPNN(
        params.proteinmpnn_model,
        RunRFdiffusion.out.outpdbs,
        params.input_pdb_chains,
        params.num_seq_per_target
    )

    if (params.fasta_path[-1] == "/") {
        fasta_path = params.fasta_path + "*"
    } else {
        fasta_path = params.fasta_path
    }

    sequences = Channel.fromPath(fasta_path)
        .splitFasta(record: [id: true, seqString: true])
        .map { record -> "${record.id}zzzz${record.seqString}" }
        .combine( RunProteinMPNN.out.fastas.flatten() )

    RunAlphaFoldMultimer(
        params.alphafold2_model,
        sequences
    )
}

process RunRFdiffusion {
    label 'rfdiffusion'
    errorStrategy 'retry'
    cpus { 2 * Math.pow(2, task.attempt) }
    memory { 8.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries params.max_retries
    publishDir "/mnt/workflow/pubdir/rfdiffusion/"

    input:
        path rfdiffusion_model
        path pdbs
        val contigs
        val num_design

    output:
        path "*.pdb", emit: outpdbs
    script:
    """
    set -ex

    export PYTHONPATH="${PYTHONPATH}:/opt/nim/"
    export MODEL_PATH=${rfdiffusion_model}

    /usr/bin/python3 /opt/nim/run_rfdiffusion.py ${pdbs} ${num_design} "${contigs}" 
    """
}

process RunProteinMPNN {
    label 'proteinmpnn'
    errorStrategy 'retry'
    cpus { 2 * Math.pow(2, task.attempt) }
    memory { 8.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries params.max_retries
    publishDir "/mnt/workflow/pubdir/proteinmpnn/"

    input:
        path proteinmpnn_model
        path inputpdbs
        val input_pdb_chains
        val num_seq_per_target

    output:
        path "*.fasta", emit: fastas
    script:
    """
    set -ex

    export PYTHONPATH="${PYTHONPATH}:/opt/"
    export MODEL_PATH=${proteinmpnn_model}

    for p in ${inputpdbs}
    do
        /usr/bin/python3 /opt/run_proteinmpnn.py \$p ${input_pdb_chains} ${num_seq_per_target}
        sleep 1
    done
    """
}

process RunAlphaFoldMultimer {
    label 'alphafoldmultimer'
    errorStrategy 'retry'
    cpus { 2 * Math.pow(2, task.attempt) }
    memory { 8.GB * Math.pow(2, task.attempt) }
    accelerator 1, type: 'nvidia-tesla-a10g'
    maxRetries params.max_retries
    publishDir "/mnt/workflow/pubdir/alphafoldmultimer/"

    input:
        path model_parameters
        val sequences

    output:
        path "*.pdb", emit: pdbs
    script:
    """
    set -euxo pipefail

    cp /opt/nim/*.py .
    export PYTHONPATH="${PYTHONPATH}:/opt/nim/:"
    export NIM_CACHE_PATH=${model_parameters}

    /usr/bin/python3 /opt/nim/run_afm.py ${sequences[0]} ${sequences[1]}
    """
}





