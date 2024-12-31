nextflow.enable.dsl = 2

process SearchUniref90 {
    tag "${record_id}"
    label 'data'
    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 32.GB * Math.pow(2, task.attempt) }
    maxRetries 3
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/msa"

    input:
        tuple val(fasta_basename), val(record_id), path(fasta_record_path)
        path database_path

    output:
        tuple val(fasta_basename), val(record_id), path("output_${record_id}/${record_id}_uniref90_hits.sto"), emit: fasta_basename_with_record_id_and_msa
        tuple val(fasta_basename), path("output_${record_id}/${record_id}_uniref90_hits.sto"), emit: fasta_basename_with_msa
        path "output_${record_id}/${record_id}_uniref90_hits.sto", emit: msa
        path "output_${record_id}/${record_id}_uniref90_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail
    cat $fasta_record_path

    mkdir -p output_${record_id}

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_record_path \
      --database_type=uniref90 \
      --database_path=$database_path \
      --output_dir=output_${record_id} \
      --cpu=$task.cpus

    mv output_${record_id}/uniref90_hits.sto output_${record_id}/${record_id}_uniref90_hits.sto
    mv output_${record_id}/metrics.json output_${record_id}/${record_id}_uniref90_metrics.json
    """
}

process SearchMgnify {
    tag "${record_id}"
    label 'data'
    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 64.GB * Math.pow(2, task.attempt) }
    maxRetries 3
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/msa"

    input:
        tuple val(fasta_basename), val(record_id), path(fasta_record_path)
        path database_path

    output:
        tuple val(fasta_basename), path("output_${record_id}/${record_id}_mgnify_hits.sto"), emit: fasta_basename_with_msa
        path "output_${record_id}/${record_id}_mgnify_hits.sto", emit: msa
        path "output_${record_id}/${record_id}_mgnify_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail
    cat $fasta_record_path
    
    mkdir -p output_${record_id}

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_record_path \
      --database_type=mgnify \
      --database_path=$database_path \
      --output_dir=output_${record_id} \
      --cpu=$task.cpus

    mv output_${record_id}/mgnify_hits.sto output_${record_id}/${record_id}_mgnify_hits.sto
    mv output_${record_id}/metrics.json output_${record_id}/${record_id}_mgnify_metrics.json
    """
}

process SearchUniprot {
    tag "${record_id}"
    label 'data'
    cpus 8
    memory '32 GB'
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/msa"

    input:
        tuple val(fasta_basename), val(record_id), path(fasta_record_path)
        path database_path

    output:
        tuple val(fasta_basename), path("output_${record_id}/${record_id}_uniprot_hits.sto"), emit: fasta_basename_with_msa
        path "output_${record_id}/${record_id}_uniprot_hits.sto", emit: msa
        path "output_${record_id}/${record_id}_uniprot_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail
    cat $fasta_record_path

    mkdir -p output_${record_id}

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_record_path \
      --database_type=uniprot \
      --database_path=$database_path \
      --output_dir=output_${record_id} \
      --cpu=$task.cpus

    mv output_${record_id}/uniprot_hits.sto output_${record_id}/${record_id}_uniprot_hits.sto
    mv output_${record_id}/metrics.json output_${record_id}/${record_id}_uniprot_metrics.json
    """
}

process SearchBFD {
    tag "${record_id}"
    label 'data'

    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 64.GB * Math.pow(2, task.attempt) }
    maxRetries 3
    errorStrategy 'retry'

    publishDir "/mnt/workflow/pubdir/${fasta_basename}/msa"

    input:
        tuple val(fasta_basename), val(record_id), path(fasta_record_path)
        path bfd_database_folder
        path uniref30_database_folder

    output:
        tuple val(fasta_basename), path("output_${record_id}/${record_id}_bfd_hits.a3m"), emit: fasta_basename_with_msa
        path "output_${record_id}/${record_id}_bfd_hits.a3m", emit: msa
        path "output_${record_id}/${record_id}_bfd_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail
    cat $fasta_record_path
    mkdir -p output_${record_id}

    /opt/venv/bin/python /opt/create_msa_monomer.py \
      --fasta_path=$fasta_record_path \
      --database_type=bfd \
      --database_path=$bfd_database_folder \
      --database_path_2=$uniref30_database_folder \
      --output_dir=output_${record_id} \
      --cpu=$task.cpus

    mv output_${record_id}/bfd_hits.a3m output_${record_id}/${record_id}_bfd_hits.a3m
    mv output_${record_id}/metrics.json output_${record_id}/${record_id}_bfd_metrics.json
    """
}

process SearchTemplatesTask {
    tag "${record_id}"
    label 'data'
    cpus 2
    memory '8 GB'
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/msa"

    input:
        tuple val(fasta_basename), val(record_id), path(msa_path)
        path pdb_db_folder

    output:
        tuple val(fasta_basename), path("output_${record_id}/${record_id}_pdb_hits.sto"), emit: fasta_basename_with_msa
        path "output_${record_id}/${record_id}_pdb_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output_${record_id}

    /opt/venv/bin/python /opt/search_templates.py \
          --msa_path=$msa_path \
          --output_dir=output_${record_id} \
          --database_path=$pdb_db_folder \
          --model_preset=multimer \
          --cpu=$task.cpus

    mv output_${record_id}/pdb_hits.sto output_${record_id}/${record_id}_pdb_hits.sto
    mv output_${record_id}/metrics.json output_${record_id}/${record_id}_pdb_metrics.json
    """
}

// Combine/rename results from parallel searches as AlphaFold expects
process CombineSearchResults {
    tag "${fasta_basename}"
    label 'data'
    cpus 4
    memory '8 GB'
    publishDir "/mnt/workflow/pubdir/${fasta_basename}/msa"

    input:
        tuple val(fasta_basename), path(fasta_path), path(uniref90_msas), path(mgnify_msas), path(uniprot_msas), path(bfd_msas), path(template_hits)  

    output: 
        tuple val(fasta_basename), path(fasta_path), path ("msa/"), emit: fasta_basename_fasta_and_msa_path
        path "msa/", emit: msa_path

    script:
    """
    echo ">>>>>>>>>>>>>>>>>>>"
    echo $fasta_basename
    echo $fasta_path
    echo $uniref90_msas
    echo $mgnify_msas
    echo $uniprot_msas
    echo $bfd_msas
    echo $template_hits
    echo "<<<<<<<<<<<<<<<<<<<"

    mkdir -p msa
    /opt/venv/bin/python /opt/update_locations.py msa _uniref90_hits.sto $uniref90_msas
    /opt/venv/bin/python /opt/update_locations.py msa _mgnify_hits.sto $mgnify_msas
    /opt/venv/bin/python /opt/update_locations.py msa _uniprot_hits.sto $uniprot_msas
    /opt/venv/bin/python /opt/update_locations.py msa _bfd_hits.a3m $bfd_msas
    /opt/venv/bin/python /opt/update_locations.py msa _pdb_hits.sto $template_hits

    echo "***********************"
    ls -alR msa/
    echo "***********************"
    """
}
