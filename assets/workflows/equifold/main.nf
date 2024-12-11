nextflow.enable.dsl = 2

workflow Equifold{

    take:
    input_csv
    model
    ncpu
    
    main:
    if(!(model in ["ab", "science"])) {
        error("model type can only be 'ab' (for antibodies), or 'science' (for mini-proteins)")
    }
    RunEquifoldPredict(
        input_csv,
        model,
        ncpu
    )

    RunEquifoldPredict.out.pdbs.collect().set {pdbs}

    emit:
    pdbs
}

process RunEquifoldPredict {
    label 'equifold'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path input_csv
        val model
        val ncpu
    output:
        path 'output/*.pdb.gz', emit: pdbs

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/conda/bin/python /home/equifold/run_inference.py --model ${model} \
        --model_dir /home/equifold/models \
        --seqs ${input_csv} \
        --ncpu ${ncpu} \
        --out_dir output
    """
}

workflow {
    Equifold(
        Channel.fromPath(params.input_csv),
        Channel.value(params.model),
        Channel.value(params.ncpu)
    )
}
