nextflow.enable.dsl = 2

workflow {

    mmseqs_db = PrepMMseqDatabases(params.mmseq_db)

    // Create a channel for all FASTA files in the directory
    fasta_files = Channel.fromPath("${params.fasta_dir}/*.fasta")

    // runs per .fa file
    alignment_dirs = PrecomputeAlignments(
        fasta_files,
        mmseqs_db.prepped_mmseq_db,
        params.pdb70
    )

    // Define the target directory for merging files
    merged_alignment_dir = file("merged_alignments")

    // Create the target directory if it doesn't exist
    merged_alignment_dir.mkdirs()

    merged_aligned_dir_chan = alignment_dirs.alignments.flatMap { d -> 
        // Get the directory within "output"
        d.listFiles()
    } | map { d ->
        // Copy the dir to our shared output
        d.copyTo(merged_alignment_dir)
        return merged_alignment_dir
    // Ensure all directories are copied
    } | last

    // Should be run once
    PretrainedOpenFold(
        params.fasta_dir,
        params.pdb_mmcif_files,
        merged_aligned_dir_chan,

        params.openfold_checkpoint
    )

}

process PrepMMseqDatabases {
    label 'openfold'
    cpus 32
    memory '128 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    input:
        path data_dir
    
    output:
        path "${data_dir}/*", emit: prepped_mmseq_db

    script:
    """
    set -euxo pipefail

    tree .
    tree ${data_dir}

    mkdir -p prep-tmp/

    bash /opt/openfold/scripts/prep_mmseqs_dbs.sh ${data_dir} prep-tmp/

    tree .
    tree ${data_dir}
    """
}

process PrecomputeAlignments {
    label 'openfold'
    cpus 32
    memory '128 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    publishDir "/mnt/workflow/pubdir"

    input:
        path fasta
        path prepped_mmseq_db
        path pdb70

    output:
        path 'output', emit: alignments

    script:
    """
    set -euxo pipefail

    mkdir -p ./output

    pwd

    tree .

    WORK="\$(realpath .)"
    FASTA="\$(realpath ${fasta})"
    MMSEQ_DB="\$(realpath ${prepped_mmseq_db})"
    PDB_70="\$(realpath ${pdb70})"

    pushd /opt/openfold

    pwd
    
    python3 /opt/openfold/scripts/precompute_alignments_mmseqs.py \$FASTA \
        \$MMSEQ_DB \
        colabfold_envdb_202108_db \
        \$WORK/output \
        /opt/conda/bin/mmseqs \
        --hhsearch_binary_path /opt/conda/bin/hhsearch \
        --env_db colabfold_envdb_202108_db \
        --pdb70 \$PDB_70/pdb70
    
    tree \$WORK
    
    pwd

    popd

    pwd
    """
}

process PretrainedOpenFold {
    label 'openfold'
    cpus 32
    memory '128 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'

    publishDir "/mnt/workflow/pubdir"

    input:
        // inputs
        path fasta_dir
        path pdb_mmcif_files
        path alignment_dir

        // ref data
        path openfold_checkpoint

    output:
        path 'output/*', emit: results

    script:
    """
    set -euxo pipefail

    mkdir -p ./output

    tree .

    tree ${fasta_dir}
    tree ${pdb_mmcif_files}
    tree ${openfold_checkpoint}

    pushd ${pdb_mmcif_files}

    for file in *.tar; do
    tar -xf "\$file"
    done

    popd

    tree ${pdb_mmcif_files}

    python3 /opt/openfold/run_pretrained_openfold.py \
        ${fasta_dir} \
        ${pdb_mmcif_files} \
        --use_precomputed_alignments ${alignment_dir} \
        --config_preset model_1_ptm \
        --output_dir ./output \
        --model_device cuda:0 \
        --openfold_checkpoint_path ${openfold_checkpoint}/finetuning_ptm_2.pt
    tree .

    """
}
