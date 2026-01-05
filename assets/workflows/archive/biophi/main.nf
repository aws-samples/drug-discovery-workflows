nextflow.enable.dsl = 2

workflow BioPhi {

    take:
    input_fasta
    humanize
    eval
    eval_option
    oas_db_path

    main:
    
    if ( humanize && eval ) {
        RunHumanizationAndEval(
            input_fasta,
            oas_db_path
        )
    }
    else if (humanize && !eval) {
        RunHumanization(input_fasta)
    }
    else if (!humanize && eval ) {
        if (eval_option == "sapien") {
            RunSapienEval(input_fasta)
        }  
        else if (eval_option == "oasis") {
            RunOASisEval(input_fasta, oas_db_path)
        }
        else {error "Error: supported eval options are 'sapien' and 'oasis'."}
    }
    else {
        println "Please specify either humanize or eval."
    }
}


process RunSapienEval {
    label 'biophi'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

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
    label 'biophi'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

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
    label 'biophi'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

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
    label 'biophi'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

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

workflow {
    BioPhi(
        Channel.fromPath(params.input_fasta),
        params.humanize,
        params.eval,
        params.eval_option,
        Channel.fromPath(params.oas_db_path)
    )
}
