nextflow.enable.dsl = 2

process SearchUniref90 {
    tag "${id}"
    label 'alphafold'
    cpus 8
    memory '32 GB'
    publishDir "/mnt/workflow/pubdir/${id}/msa"

    input:
        tuple val(id), path(fasta_path)
        path database_path

    output:
        tuple val(id), path("output_${id}/uniref90_hits.sto"), emit: msa
        path "output_${id}/uniref90_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail
    mv $fasta_path ${id}.fa
    cat ${id}.fa

    mkdir -p output_${id}

    /opt/venv39-afdata/bin/python /opt/create_msa_monomer.py \
      --fasta_path=${id}.fa \
      --database_type=uniref90 \
      --database_path=$database_path \
      --output_dir=output_${id} \
      --cpu=$task.cpus

    mv output_${id}/metrics.json output_${id}/uniref90_metrics.json
    md5sum output_${id}/uniref90_hits.sto
    """
}

process SearchMgnify {
    tag "${id}"
    label 'alphafold'
    cpus 8
    memory '64 GB'
    publishDir "/mnt/workflow/pubdir/${id}/msa"

    input:
        tuple val(id), path(fasta_path)
        path database_path

    output:
        tuple val(id), path("output_${id}/mgnify_hits.sto"), emit: msa
        path "output_${id}/mgnify_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail
    mv $fasta_path ${id}.fa
    cat ${id}.fa
    mkdir -p output_${id}

    /opt/venv39-afdata/bin/python /opt/create_msa_monomer.py \
      --fasta_path=${id}.fa \
      --database_type=mgnify \
      --database_path=$database_path \
      --output_dir=output_${id} \
      --cpu=$task.cpus

    mv output_${id}/metrics.json output_${id}/mgnify_metrics.json
    md5sum output_${id}/mgnify_hits.sto
    """
}

process SearchBFD {
    tag "${id}"
    label 'alphafold'

    cpus { 8 * Math.pow(2, task.attempt) }
    memory { 64.GB * Math.pow(2, task.attempt) }
    maxRetries 1
    errorStrategy 'retry'

    publishDir "/mnt/workflow/pubdir/${id}/msa"

    input:
        tuple val(id), path(fasta_path)
        path bfd_database_folder
        path uniref30_database_folder

    output:
        tuple val(id), path("output_${id}/bfd_uniref_hits.a3m"), emit: msa
        path "output_${id}/bfd_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail
    mv $fasta_path ${id}.fa
    cat ${id}.fa
    mkdir -p output_${id}

    /opt/venv39-afdata/bin/python /opt/create_msa_monomer.py \
      --fasta_path=${id}.fa \
      --database_type=bfd \
      --database_path=$bfd_database_folder \
      --database_path_2=$uniref30_database_folder \
      --output_dir=output_${id} \
      --cpu=$task.cpus

    mv output_${id}/metrics.json output_${id}/bfd_metrics.json
    mv output_${id}/bfd_hits.a3m output_${id}/bfd_uniref_hits.a3m
    md5sum output_${id}/bfd_uniref_hits.a3m
    """
}

process SearchTemplatesTask {
    tag "${id}"
    label 'alphafold'
    cpus 2
    memory '8 GB'
    publishDir "/mnt/workflow/pubdir/${id}/msa"

    input:
        tuple val(id), path(msa_path)
        path pdb_db_folder

    output:
        tuple val(id), path("output_${id}/pdb_hits.hhr"), emit: pdb_hits
        path "output_${id}/pdb_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output_${id}

    /opt/venv39-afdata/bin/python /opt/search_templates.py \
          --msa_path=$msa_path \
          --output_dir=output_${id} \
          --database_path=$pdb_db_folder \
          --model_preset=monomer_ptm \
          --cpu=$task.cpus

    mv output_${id}/metrics.json output_${id}/pdb_metrics.json
    """
}
