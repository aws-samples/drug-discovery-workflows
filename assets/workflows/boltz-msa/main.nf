#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow BoltzMsa {
    take:
    input_path
    boltz_parameters
    uniref30_db_path
    envdb_db_path
    pdb100_db_path
    is_complex

    main:

    input_channel = Channel.fromPath(input_path)

    // Extract protein sequences from input YAML
    ExtractProteins(input_channel)

    // Prepare database channels for ColabFold search
    uniref30_db_channel = Channel.fromPath(
        uniref30_db_path.endsWith("/") ? uniref30_db_path + "*" : uniref30_db_path + "/*"
    )
    envdb_db_channel = Channel.fromPath(
        envdb_db_path.endsWith("/") ? envdb_db_path + "*" : envdb_db_path + "/*"
    )
    pdb100_db_channel = Channel.fromPath(
        pdb100_db_path.endsWith("/") ? pdb100_db_path + "*" : pdb100_db_path + "/*"
    )
    db_channel = uniref30_db_channel.concat(envdb_db_channel, pdb100_db_channel).collect()

    // Check if we have proteins by reading the flag file
    has_proteins_channel = ExtractProteins.out.has_proteins
        .splitText()
        .map { it.trim() == "true" }

    // Combine fasta with has_proteins flag
    fasta_with_flag = ExtractProteins.out.fasta
        .combine(has_proteins_channel)

    // Filter to only run MSA search if proteins exist
    fasta_for_msa = fasta_with_flag
        .filter { fasta, has_proteins -> has_proteins }
        .map { fasta, has_proteins -> fasta }

    // Run ColabFold search only if proteins exist
    ColabfoldSearchTask(
        fasta_for_msa,
        db_channel,
        is_complex
    )

    // Collect MSA files into a directory structure
    msa_dir = ColabfoldSearchTask.out.msa.collect().ifEmpty([])

    // Combine inputs for UpdateYamlWithMsa
    yaml_update_inputs = input_channel
        .combine(ExtractProteins.out.protein_map)
        .combine(msa_dir)
        .combine(has_proteins_channel)

    // Only update YAML if proteins exist
    yaml_to_update = yaml_update_inputs
        .filter { yaml, protein_map, msa, has_proteins -> has_proteins }
        .map { yaml, protein_map, msa, has_proteins -> tuple(yaml, protein_map, msa) }

    // Update YAML with MSA paths (only if proteins exist)
    UpdateYamlWithMsa(
        yaml_to_update.map { it[0] },
        yaml_to_update.map { it[1] },
        yaml_to_update.map { it[2] }
    )

    // Prepare Boltz parameters channel
    boltz_params_channel = Channel.fromPath(boltz_parameters)

    // Determine which YAML to use for Boltz prediction
    // If proteins exist, use updated YAML; otherwise use original
    yaml_for_boltz = UpdateYamlWithMsa.out.updated_yaml
        .mix(
            yaml_update_inputs
                .filter { yaml, protein_map, msa, has_proteins -> !has_proteins }
                .map { yaml, protein_map, msa, has_proteins -> yaml }
        )

    // Run Boltz prediction
    Boltz2Task(
        yaml_for_boltz,
        boltz_params_channel
    )

    emit:
    proteins_fasta = ExtractProteins.out.fasta
    protein_map = ExtractProteins.out.protein_map
    msa_files = ColabfoldSearchTask.out.msa
    template_hits = ColabfoldSearchTask.out.template_hits
    updated_yaml = UpdateYamlWithMsa.out.updated_yaml
    boltz_output = Boltz2Task.out.output
}

process ExtractProteins {
    label 'boltz'
    cpus 2
    memory '4 GB'
    errorStrategy 'retry'
    maxRetries 2
    time '30m'
    publishDir "/mnt/workflow/pubdir/input", mode: 'copy', pattern: "*.yaml"
    publishDir "/mnt/workflow/pubdir/intermediate", mode: 'copy', pattern: "*.{fasta,json,txt}"

    input:
    path input_yaml

    output:
    path input_yaml, emit: original_yaml
    path "proteins.fasta", emit: fasta
    path "protein_map.json", emit: protein_map
    path "has_proteins.txt", emit: has_proteins

    script:
    """
    set -euxo pipefail

    # Run the protein extraction script
    python3 /opt/extract_proteins.py \\
        ${input_yaml} \\
        --fasta proteins.fasta \\
        --map protein_map.json \\
        --has-proteins-flag has_proteins.txt

    # Display results for debugging
    echo "Extraction complete"
    if [ -s proteins.fasta ]; then
        echo "Found proteins:"
        grep "^>" proteins.fasta || true
    else
        echo "No proteins found in input YAML"
    fi
    """
}

process UpdateYamlWithMsa {
    label 'boltz'
    cpus 2
    memory '4 GB'
    errorStrategy 'retry'
    maxRetries 2
    time '30m'
    publishDir "/mnt/workflow/pubdir/updated_yaml", mode: 'copy'

    input:
    path input_yaml
    path protein_map
    path msa_dir

    output:
    path "updated_input.yaml", emit: updated_yaml

    script:
    """
    set -euxo pipefail

    # Run the YAML update script
    python3 /opt/update_yaml_with_msa.py \\
        ${input_yaml} \\
        ${protein_map} \\
        ${msa_dir} \\
        --output updated_input.yaml

    # Display results for debugging
    echo "YAML update complete"
    echo "Updated YAML content:"
    cat updated_input.yaml
    """
}

process ColabfoldSearchTask {
    label 'mmseqs2'
    cpus 64
    memory '486 GB'
    errorStrategy 'retry'
    maxRetries 2
    time '6h'
    accelerator 1, type: 'nvidia-l40s'
    publishDir "/mnt/workflow/pubdir/msa", mode: 'copy', pattern: "*.a3m"
    publishDir "/mnt/workflow/pubdir/templates", mode: 'copy', pattern: "*.m8"

    input:
    path query
    path db, stageAs: 'db/*'
    val is_complex

    output:
    path "*.a3m", emit: msa
    path "*.m8", emit: template_hits

    script:
    """
    set -euxo pipefail

    # Remove any model-specific content in the description
    # Produces a new, "clean.fasta" file
    bash /home/clean_fasta.sh ${query}

    bash /home/msa.sh \\
      /usr/local/bin/mmseqs \\
      clean.fasta \\
      . \\
      db/uniref30_2302_db \\
      db/pdb100_230517 \\
      db/colabfold_envdb_202108_db \\
      1 1 1 0 0 1

    if [[ ${is_complex} -eq 1 ]]; then
      bash /home/pair.sh \\
        /usr/local/bin/mmseqs \\
        clean.fasta \\
        . \\
        db/uniref30_2302_db \\
        "" 0 1 0 1
    fi

    rm clean.fasta
    """
}

process Boltz2Task {
    label 'boltz'
    cpus 4
    memory '16 GB'
    errorStrategy 'retry'
    maxRetries 2
    time '4h'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/boltz_predictions", mode: 'copy', saveAs: { filename -> filename.replaceFirst(/^output\//, '') }

    input:
    path input_path
    path boltz_parameters

    output:
    path "output/**", emit: output

    script:
    """
    set -euxo pipefail
    mkdir output

    # Extract CCD data
    /usr/bin/tar -xf $boltz_parameters/mols.tar -C $boltz_parameters

    /opt/venv/bin/boltz predict \\
      --cache $boltz_parameters \\
      --out_dir output \\
      $input_path
    """
}

workflow {
    BoltzMsa(
        params.input_path,
        params.boltz_parameters,
        params.uniref30_db_path,
        params.envdb_db_path,
        params.pdb100_db_path,
        params.is_complex
    )
}
