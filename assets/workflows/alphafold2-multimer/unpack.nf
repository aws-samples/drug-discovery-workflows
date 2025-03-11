// Utilities to unpack/organize certain MSA databases

process UnpackBFD {
    label 'alphafold'
    cpus 2
    memory '4 GB'
    // Don't publish - we don't want copies of the databases

    input:
        path bfd_database_a3m_ffdata
        path bfd_database_a3m_ffindex
        path bfd_database_cs219_ffdata
        path bfd_database_cs219_ffindex
        path bfd_database_hhm_ffdata
        path bfd_database_hhm_ffindex

    output:
        path "bfd/", emit: db_folder

    script:
    """
    set -euxo pipefail

    # BFD
    mkdir -p bfd
    mv $bfd_database_a3m_ffdata bfd/
    mv $bfd_database_a3m_ffindex bfd/
    mv $bfd_database_cs219_ffdata bfd/
    mv $bfd_database_cs219_ffindex bfd/
    mv $bfd_database_hhm_ffdata bfd/
    mv $bfd_database_hhm_ffindex bfd/
    """
}


process UnpackUniprot {
    label 'alphafold'
    cpus 4
    memory '8 GB'
    // Don't publish - we don't want copies of the databases

    input:
        path uniprot_database_src
        path base_database_path

    output:
        path "$base_database_path/uniprot/uniprot.fasta", emit: db

    script:
    """
    set -euxo pipefail

    # Uniref30
    mkdir -p $base_database_path/uniprot
    tar -xvf $uniprot_database_src -C $base_database_path/uniprot
    """
}


process UnpackPdb70nSeqres {
    label 'alphafold'
    cpus 2
    memory '4 GB'
    // Don't publish - we don't want copies of the databases

    input:
        path pdb70_src
        path pdb_seqres_src
        val base_database_path

    output:
        path "$base_database_path/pdb/", emit: db_folder
        path "$base_database_path/pdb/pdb_seqres.txt", emit: db_seqres

    script:
    """
    set -euxo pipefail

    # Templates - pdb70 and seqres
    mkdir -p $base_database_path/pdb
    mv $pdb70_src/* $base_database_path/pdb/
    
    # filter strange sequences containing 0
    /opt/venv39-afdata/bin/python /opt/filter_pdb.py $pdb_seqres_src $base_database_path/pdb/pdb_seqres.txt
    ls -laR $base_database_path/pdb/
    """
}


process UnpackMMCIF {
    label 'alphafold'
    cpus 2
    memory '4 GB'
    // Don't publish - we don't want copies of the databases

    input:
        path pdb_mmcif_src1
        path pdb_mmcif_src2
        path pdb_mmcif_src3
        path pdb_mmcif_src4
        path pdb_mmcif_src5
        path pdb_mmcif_src6
        path pdb_mmcif_src7
        path pdb_mmcif_src8
        path pdb_mmcif_src9
        path pdb_mmcif_obsolete
    
    output:
        path "pdb_mmcif/mmcif_files/", emit: db_folder
        path "pdb_mmcif/obsolete.dat", emit: db_obsolete

    script:
    """
    set -euxo pipefail
    mkdir pdb_mmcif
    mkdir pdb_mmcif/mmcif_files/
    mv $pdb_mmcif_obsolete pdb_mmcif/
    ls -alR

    # Features
    tar -xf $pdb_mmcif_src1 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src2 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src3 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src4 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src5 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src6 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src7 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src8 -C pdb_mmcif/mmcif_files/
    tar -xf $pdb_mmcif_src9 -C pdb_mmcif/mmcif_files/
    """
}


process UnpackRecords {
    tag "${id}"
    label 'alphafold'
    cpus 2
    memory '4 GB'
    publishDir "/mnt/workflow/pubdir/${id}/input"
    
    input:
        tuple val(id), val(header), val(seqString)

    output:
        tuple val(id), path("input.fasta"), emit: fasta

    script:
    """
    set -euxo pipefail
    echo -e ">${header}\n${seqString}" > input.fasta
    """
}