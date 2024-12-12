nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    if ( params.humanize && params.eval) {
        // run the full humanization and eval
        RunHumanizationAndEval(
            params.input_fasta,
            params.oas_db_path
        )
        }
    else if (params.humanize && !params.eval) {
        // only run humanization
        RunHumanization(params.input_fasta)
        }
    else if (!params.humanize && params.eval) {
        // only run eval
        if (params.eval_option == "sapien") {
            RunSapienEval(params.input_fasta)
        }
        else if (params.eval_option == "oasis") {
            RunOASisEval(
                params.input_fasta,
                params.oas_db_path
            )
        }
        else {error "Error: supported eval options are 'sapien' and 'oasis'."}
    }
}


process RunSapienEval {
    container '588738610715.dkr.ecr.us-east-1.amazonaws.com/biophi:latest'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path input_fasta
        
    output:
        path '*.csv', emit: csvs

    script:
    """
    set -euxo pipefail
    biophi sapiens ${input_fasta}\
        --scores-only \
        --output scores.csv
    """
}

process RunOASisEval {
    container '588738610715.dkr.ecr.us-east-1.amazonaws.com/biophi:latest'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path input_fasta
        path oas_db_path
        
    output:
        path '*.xlsx', emit: xlsxs

    script:
    """
    set -euxo pipefail
    biophi oasis ${input_fasta} \
        --oasis-db ${oas_db_path} \
        --output oasis.xlsx
    """
}

process RunHumanization {
    container '588738610715.dkr.ecr.us-east-1.amazonaws.com/biophi:latest'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path input_fasta
        
    output:
        path '*.fa', emit: fastas

    script:
    """
    set -euxo pipefail
    biophi sapiens ${input_fasta} \
        --fasta-only \
        --output humanized.fa
    """
}

process RunHumanizationAndEval {
    container '588738610715.dkr.ecr.us-east-1.amazonaws.com/biophi:latest'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path input_fasta
        path oas_db_path
    
    output:
        path 'humanized/*'

    script:
    """
    set -euxo pipefail
    biophi sapiens ${input_fasta} \
        --oasis-db ${oas_db_path} \
        --output humanized/
    """
}