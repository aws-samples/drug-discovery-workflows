nextflow.enable.dsl = 2

workflow HumatchClassifyAndHumanise {
    take:
    params

    main:
    input_csv = Channel.fromPath(params.input_csv)

    config = GenerateConfig(params)

    aligned = HumatchAlign(input_csv)

    classified = HumatchClassify(aligned)
    humanized = HumatchHumanise(aligned, config)

    emit:
    classified
    humanized
}

// Alignment columns are hardcoded output as VH / VL vs original input columns heavy / light
// Also see --imgt_cols flag https://github.com/lewis-chinery/Humatch/blob/master/Humatch/align.py#L71
process HumatchAlign {
    tag "${input_csv}"
    label "humatch"

    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path input_csv
    output:
        path "aligned_output.csv"

    script:
    """
    set -euxo pipefail

    Humatch-align \
       -i ${input_csv} \
        -o aligned_output.csv \
        --vh_col heavy \
        --vl_col light 
    """
}


process HumatchClassify {
    tag "${aligned_csv}"
    label "humatch"

    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path aligned_csv

    output:
        path "classify_output.csv"

    script:
    """
    set -euxo pipefail

    Humatch-classify \
        -i ${aligned_csv} \
        --aligned \
        -o classify_output.csv \
        --vh_col VH \
        --vl_col VL
    """

}

process HumatchHumanise {
    tag "${aligned_csv}"
    label "humatch"

    accelerator 1, type: 'nvidia-tesla-a10g'
    // omics.c.4xlarge
    cpus { 16 }
    memory { 32.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path aligned_csv
        path config
    output:
        path "humanised_output.csv"

    script:
    """
    set -euxo pipefail

    cat ${config}
    yq -i '.num_cpus = $task.cpus' ${config}
    cat ${config}

    Humatch-humanise \
        -i ${aligned_csv} \
        --aligned \
        -o humanised_output.csv \
        --vh_col VH \
        --vl_col VL \
        --config ${config}
    """
}

process GenerateConfig {
    label "humatch"

    // omics.c.large
    cpus { 2 }
    memory { 4.GB }

    input:
        val params

    output:
        file("config.yaml")

    script:

    // Ensure that the paths are quoted correctly in bash to handle spaces
    def quoteEscape = { param -> param.toString().replaceAll('"', '\\"') } 
    def quoteParam = { param -> "\"${quoteEscape(param)}\"" }
    def quoteList = { list -> list.collect { quoteParam(it) }.join(' ') }
    
    """
    set -euxo pipefail

    echo \$PATH
    echo \$PYTHONPATH

    /opt/miniconda/bin/python3 /opt/generate_config.py \
        --max_edit ${quoteParam(params.max_edit)} \
        --noise ${quoteParam(params.noise)} \
        --num_cpus ${quoteParam(params.num_cpus)} \
        --GL_target_score_H ${quoteParam(params.GL_target_score_H)} \
        --GL_allow_CDR_mutations_H ${quoteParam(params.GL_allow_CDR_mutations_H)} \
        --GL_fixed_imgt_positions_H ${quoteList(params.GL_fixed_imgt_positions_H)} \
        --CNN_target_score_H ${quoteParam(params.CNN_target_score_H)} \
        --CNN_allow_CDR_mutations_H ${quoteParam(params.CNN_allow_CDR_mutations_H)} \
        --CNN_fixed_imgt_positions_H ${quoteList(params.CNN_fixed_imgt_positions_H)} \
        --GL_target_score_L ${quoteParam(params.GL_target_score_L)} \
        --GL_allow_CDR_mutations_L ${quoteParam(params.GL_allow_CDR_mutations_L)} \
        --GL_fixed_imgt_positions_L ${quoteList(params.GL_fixed_imgt_positions_L)} \
        --CNN_target_score_L ${quoteParam(params.CNN_target_score_L)} \
        --CNN_allow_CDR_mutations_L ${quoteParam(params.CNN_allow_CDR_mutations_L)} \
        --CNN_fixed_imgt_positions_L ${quoteList(params.CNN_fixed_imgt_positions_L)} \
        --CNN_target_score_P ${quoteParam(params.CNN_target_score_P)} \
        --output config.yaml
    """
}

workflow  {
    HumatchClassifyAndHumanise(params)
}
