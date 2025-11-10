nextflow.enable.dsl = 2

workflow ANTIPASTI {
    take:
    input_pdb
    renew_maps
    renew_residues
    n_filters
    filter_size
    pooling_size
    n_max_epochs
    modes
    stage
    sabdab_db

    main:
    extracted_sabdab_db = PrepDependencies(
        Channel.fromPath(sabdab_db),
    )

    // Convert to one or many files
    if (input_pdb[-1] == "/") {
        input_pdb = input_pdb + "*"
    } else {
        input_pdb = input_pdb
    }

    pdb_files = Channel.fromPath(input_pdb)

    scores = PredictBindingAffinity(
        pdb_files.collect(),
        renew_maps, 
        renew_residues,
        n_filters,
        filter_size,
        pooling_size,
        n_max_epochs,
        modes,
        stage,
        extracted_sabdab_db,
    )

    emit:
    scores
}

process PrepDependencies {
    label "antipasti"

    // omics.c.large
    cpus { 2 }
    memory { 4.GB }

    input:
        path sabdab_db

    output:
        path "all_structures/", emit: extracted_sabdab_db

    script:
        """
        set -euxo pipefail

        unzip ${sabdab_db} -d .

        """
}

process PredictBindingAffinity {
    label "antipasti"

    // omics.c.4xlarge
    accelerator 1, type: 'nvidia-tesla-a10g'
    cpus { 4 }
    memory { 16.GB }
    publishDir "/mnt/workflow/pubdir"

    input:
        val input_pdb
        val renew_maps
        val renew_residues
        val n_filters
        val filter_size
        val pooling_size
        val n_max_epochs
        val modes
        val stage
        path extracted_sabdab_db

    output:
        path "predicted_binding_affinity.csv", emit: predicted_binding_affinity

    script:

    def renew_maps_cli = renew_maps ? "--renew_maps" : ""
    def renew_residues_cli = renew_residues ? "--renew_residues" : ""

    """
    set -euxo pipefail

    tree .

    cp ${input_pdb.join(' ')} /opt/ANTIPASTI/notebooks/test_data/structure/

    extracted_sabdab_db_realpath=\$(realpath ${extracted_sabdab_db})

    pushd /opt/ANTIPASTI/notebooks

    python /opt/predict.py \
        --test_data_path /opt/ANTIPASTI/notebooks/test_data/ \
        --structures_path \$extracted_sabdab_db_realpath/chothia/ \
        --test_pdb ${input_pdb.join(' ')} \
        ${renew_residues_cli} \
        ${renew_maps_cli} \
        --n_filters ${n_filters} \
        --filter_size ${filter_size} \
        --pooling_size ${pooling_size} \
        --n_max_epochs ${n_max_epochs} \
        --modes ${modes} \
        --stage ${stage} \
        --output_csv predicted_binding_affinity.csv

    output_file=\$(realpath predicted_binding_affinity.csv)

    popd

    cp \$output_file .

    ls -lah .
    tree .
    """
}

workflow  {
    ANTIPASTI(
        params.input_pdb,
        params.renew_maps,
        params.renew_residues,
        params.n_filters,
        params.filter_size,
        params.pooling_size,
        params.n_max_epochs,
        params.modes,
        params.stage,
        params.sabdab_db,
    )
}
