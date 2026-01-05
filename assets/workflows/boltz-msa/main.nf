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

    emit:
    proteins_fasta = ExtractProteins.out.fasta
    protein_map = ExtractProteins.out.protein_map
    has_proteins = ExtractProteins.out.has_proteins
}

process ExtractProteins {
    label 'boltz'
    cpus 2
    memory '4 GB'
    errorStrategy 'retry'
    maxRetries 2
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path input_yaml

    output:
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
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

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
