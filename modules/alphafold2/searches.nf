nextflow.enable.dsl = 2

process SearchUniref90 {
    tag "${id}"
    label 'data'
    cpus 8
    memory '32 GB'
    publishDir "/mnt/workflow/pubdir/${id}"

    input:
        tuple val(id), path(fasta_path)
        path database_path

    output:
        path "output/uniref90_hits.sto", emit: msa
        path "output/uniref90_metrics.json", emit: metrics

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

    mv output/metrics.json output/uniref90_metrics.json
    """
}

process SearchMgnify {
    tag "${id}"
    label 'data'
    cpus 8
    memory '64 GB'
    publishDir "/mnt/workflow/pubdir/${id}"

    input:
        tuple val(id), path(fasta_path)
        path database_path

    output:
        path "output/mgnify_hits.sto", emit: msa
        path "output/mgnify_metrics.json", emit: metrics

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
    
    mv output/metrics.json output/mgnify_metrics.json
    """
}

process SearchBFD {
    tag "${id}"
    label 'data'
    cpus 16
    memory '128 GB'
    publishDir "/mnt/workflow/pubdir/${id}"

    input:
        tuple val(id), path(fasta_path)
        path bfd_database_folder
        path uniref30_database_folder

    output:
        path "output/bfd_hits.a3m", emit: msa
        path "output/bfd_metrics.json", emit: metrics

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

    mv output/metrics.json output/bfd_metrics.json

    """
}

process SearchTemplatesTask {
    tag "${id}"
    label 'data'
    cpus 2
    memory '8 GB'
    publishDir "/mnt/workflow/pubdir/${id}"

    input:
        tuple val(id), path(fasta_path)
        path msa_path
        path pdb_db_folder

    output:
        path "output/pdb_hits.hhr", emit: pdb_hits
        path "output/pdb_metrics.json", emit: metrics

    script:
    """
    set -euxo pipefail

    mkdir -p output

    /opt/venv/bin/python /opt/search_templates.py \
          --msa_path=$msa_path \
          --output_dir=output \
          --database_path=$pdb_db_folder \
          --model_preset=monomer_ptm \
          --cpu=$task.cpus
    
    mv output/metrics.json output/pdb_metrics.json
    """
}
