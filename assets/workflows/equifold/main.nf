nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    if(!(params.model in ["ab", "science"])) {
        error("model type can only be 'ab' (for antibodies), or 'science' (for mini-proteins)")
    }
    RunEquifoldPredict(
        params.input_csv,
        params.model,
        params.ncpu
    )
}


process RunEquifoldPredict {
    container '588738610715.dkr.ecr.us-east-1.amazonaws.com/equifold:latest'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir/'

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
