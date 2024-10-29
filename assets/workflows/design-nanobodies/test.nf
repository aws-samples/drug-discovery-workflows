nextflow.enable.dsl = 2

workflow Test {
    take:
    fasta_path

    main:

    fasta_path.view()

    fasta_path
        .collectFile(name: 'temp.fasta')
        .view()
}

workflow {
    Test(
        Channel.fromPath(params.fasta_path)
    )
}
