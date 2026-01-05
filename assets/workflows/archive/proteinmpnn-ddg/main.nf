nextflow.enable.dsl = 2

workflow ProteinMPNNddG {
    take:
    params

    main:
    input_pdb = Channel.fromPath(params.input_pdb)

    chain_to_predict = params.chain_to_predict ?: ""
    without_ddg_correction = params.without_ddg_correction ?: ""

    predicted = Predict(
        input_pdb,
        params.chains,
        params.seed,
        params.nrepeats,
        params.model_name,
        chain_to_predict,
        without_ddg_correction
    )

    emit:
    predicted
}


process Predict {
    tag "${input_pdb}"
    label "proteinmpnnddg"

    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path input_pdb
        val chains
        val seed
        val nrepeats
        val model_name
        val chains_to_predict
        val without_ddg_correction
    output:
        path "output/proteinmpnn_predictions.csv"

    script:
    def chains_predict = chains_to_predict ? "--chain_to_predict ${chains_to_predict}" : ""
    def without_ddg_correction_flag = without_ddg_correction ? "--without_ddg_correction" : ""

    """
    set -euxo pipefail

    mkdir -p output
    out_dir=\$(realpath output)
    pdb_path=\$(realpath ${input_pdb})

    pushd /app/proteinmpnn_ddg

    poetry run python /app/proteinmpnn_ddg/predict.py \
        --pdb_path \${pdb_path} \
        --chains ${chains} \
        ${chains_predict} \
        --seed ${seed} \
        --nrepeats ${nrepeats} \
        --model_name ${model_name} \
        ${without_ddg_correction_flag} \
        --outpath \${out_dir}/proteinmpnn_predictions.csv

    popd
    ls -lah output
    """
}

workflow  {
    ProteinMPNNddG(params)
}
