nextflow.enable.dsl = 2

process SearchUniref90 {
    label 'data'
    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 32.GB * Math.pow(2, task.attempt) }
    maxRetries 3
    publishDir '/mnt/workflow/pubdir/msa'

    input:
        tuple val(id), path(fasta_path)
        path database_path

    output:
        tuple val(id), path("output/${id}_uniref90_hits.sto"), emit: msa_with_id
        path "output/${id}_uniref90_hits.sto", emit: msa
        path "output/${id}_uniref90_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_path \
      --database_type=uniref90 \
      --database_path=$database_path \
      --output_dir=output \
      --cpu=$task.cpus

    mv output/uniref90_hits.sto output/${id}_uniref90_hits.sto
    mv output/metrics.json output/${id}_uniref90_metrics.json
    """
}

process SearchUniprot {
    label 'data'
    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 32.GB * Math.pow(2, task.attempt) }
    maxRetries 3
    publishDir '/mnt/workflow/pubdir/msa'

    input:
        tuple val(id), path(fasta_path)
        path database_path

    output:
        path "output/${id}_uniprot_hits.sto", emit: msa
        path "output/${id}_uniprot_metrics.json", emit: metrics
        val "$id", emit: id

    script:
    """
    set -euxo pipefail

    mkdir -p output

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_path \
      --database_type=uniprot \
      --database_path=$database_path \
      --output_dir=output \
      --cpu=$task.cpus

    mv output/uniprot_hits.sto output/${id}_uniprot_hits.sto
    mv output/metrics.json output/${id}_uniprot_metrics.json
    """
}

process SearchMgnify {
    label 'data'
    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 64.GB * Math.pow(2, task.attempt) }
    maxRetries 3
    publishDir '/mnt/workflow/pubdir/msa'

    input:
        tuple val(id), path(fasta_path)
        path database_path

    output:
        path "output/${id}_mgnify_hits.sto", emit: msa
        path "output/${id}_mgnify_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_path \
      --database_type=mgnify \
      --database_path=$database_path \
      --output_dir=output \
      --cpu=$task.cpus

    mv output/mgnify_hits.sto output/${id}_mgnify_hits.sto
    mv output/metrics.json output/${id}_mgnify_metrics.json
    """
}

process SearchBFD {
    label 'data'
    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 64.GB * Math.pow(2, task.attempt) }
    maxRetries 3
    errorStrategy 'retry'
    publishDir '/mnt/workflow/pubdir/msa'

    input:
        tuple val(id), path(fasta_path)
        path bfd_database_folder
        path uniref30_database_folder

    output:
        path "output/${id}_bfd_uniref_hits.a3m", emit: msa
        path "output/${id}_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_path \
      --database_type=bfd \
      --database_path=$bfd_database_folder \
      --database_path_2=$uniref30_database_folder \
      --output_dir=output \
      --cpu=$task.cpus

    mv output/bfd_hits.a3m output/${id}_bfd_uniref_hits.a3m
    mv output/metrics.json output/${id}_metrics.json
    """
}

process SearchTemplatesTask {
    label 'data'
    cpus 2
    memory '8 GB'
    publishDir '/mnt/workflow/pubdir/msa'

    input:
        tuple val(id), path(msa_path)
        path pdb_db_folder

    output:
        path "output/${id}_pdb_hits.sto", emit: msa
        path "output/${id}_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output

    /opt/venv/bin/python /opt/search_templates.py \
          --msa_path=$msa_path \
          --output_dir=output \
          --database_path=$pdb_db_folder \
          --model_preset=multimer \
          --cpu=$task.cpus

    mv output/pdb_hits.sto output/${id}_pdb_hits.sto
    mv output/metrics.json output/${id}_metrics.json
    """
}

// Combine/rename results from parallel searches as AlphaFold expects
process CombineSearchResults {
    label 'data'
    cpus 4
    memory '8 GB'

    input:
        path uniref90_msas
        path uniprot_msas
        path mgnify_msas
        path bfd_msas
        path template_hits
    output:
        path 'msa/', emit: msa_path

    script:
    """
    echo ">>>>>>>>>>>>>>>>>>>"
    echo $uniref90_msas
    echo $uniprot_msas
    echo $mgnify_msas
    echo $template_hits
    echo "<<<<<<<<<<<<<<<<<<<"

    mkdir -p msa
    /opt/venv/bin/python /opt/update_locations.py msa $uniref90_msas
    /opt/venv/bin/python /opt/update_locations.py msa $uniprot_msas
    /opt/venv/bin/python /opt/update_locations.py msa $mgnify_msas
    /opt/venv/bin/python /opt/update_locations.py msa $bfd_msas
    /opt/venv/bin/python /opt/update_locations.py msa $template_hits

    echo "***********************"
    ls -alR msa/
    echo "***********************"
    """
}
