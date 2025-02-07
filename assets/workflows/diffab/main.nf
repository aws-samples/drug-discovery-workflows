nextflow.enable.dsl = 2

workflow DiffAb {
    take:
    params

    main:
    config_and_deps = GenerateConfigAndPrepDependencies(
        Channel.fromPath(params.model_weights).collect(),
        Channel.fromPath(params.sabdab_db),

        params.checkpoint_filename,
        params.seed,
        params.sample_structure,
        params.sample_sequence,
        params.cdrs,
        params.num_samples
    )

    DesignPDB(
        Channel.fromPath(params.input_pdb),
        config_and_deps.config,
        config_and_deps.checkpoint,
        config_and_deps.extracted_sabdab_db,
    )
}


process GenerateConfigAndPrepDependencies {
    label "diffab"

    // omics.c.large
    cpus { 2 }
    memory { 4.GB }

    input:
        val model_weights
        path sabdab_db

        val checkpoint
        val seed
        val sample_structure
        val sample_sequence
        val cdrs
        val num_samples

    output:
        path "config.yaml", emit: config
        path "trained_models/${checkpoint}", emit: checkpoint
        path "all_structures/", emit: extracted_sabdab_db

    script:
        // Ensure that the paths are quoted correctly in bash to handle spaces
        def quoteEscape = { param -> param.toString().replaceAll('"', '\\"') } 
        def quoteParam = { param -> "\"${quoteEscape(param)}\"" }
        def quoteList = { list -> list.collect { quoteParam(it) }.join(' ') }
        
        """
        set -euxo pipefail

        # Extract the trained models and sabdab db to be returned
        mkdir -p ./trained_models
        cp ${model_weights.join(' ')} ./trained_models
        unzip ${sabdab_db} -d .

        # Generate the configuration file for DiffAb
        python /opt/generate_config.py \
            --checkpoint ${quoteParam(checkpoint)} \
            --chothia_dir ./all_structures/chothia \
            --seed ${quoteParam(seed)} \
            --sample_structure ${quoteParam(sample_structure)} \
            --sample_sequence ${quoteParam(sample_sequence)} \
            --cdrs ${quoteList(cdrs)} \
            --num_samples ${quoteParam(num_samples)} \
            --summary_path /opt/diffab/data/sabdab_summary_all.tsv \
            --processed_dir ./processed \
            --output config.yaml
        """
}

process DesignPDB {
    tag "${input_pdb}"
    label "diffab"

    // omics.c.4xlarge
    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        path input_pdb
        path config

        // Not used in script block but:
        // config file assumes checkpoint and extracted_sabdab_db will be available in the working directory.
        // see GenerateConfigAndPrepDependencies
        path checkpoint
        path extracted_sabdab_db

    output:
        // What is the purposed of processed? Cache? Why don't I see it in the dir listing after script finishes?
        // path "processed/", emit: processed
        path "results/", emit: results

    script:
    """
    set -euxo pipefail

    cat ${config}
    tree .

    python /opt/diffab/design_pdb.py ${input_pdb} \
	    --config ${config}

    ls -lah .
    tree .
    """
}


workflow  {
    DiffAb(params)
}
