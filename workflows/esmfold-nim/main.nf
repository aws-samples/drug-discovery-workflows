nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    //Convert to files
    if (params.fasta_path[-1] == "/") {
        fasta_path = params.fasta_path + "*"
    } else {
        fasta_path = params.fasta_path
    }

    sequences = Channel.fromPath(fasta_path)
        .collectFile(name: 'temp.fasta')
        .splitFasta(record: [id: true, seqString: true])
        .filter ( record -> record.seqString.size() <= 1024 )
        .map { record -> "${record.id}zzzz${record.seqString} " }
        .collectFile(name: 'combined_seqs.txt')

    RunInference(params.model, 
                 params.weights,
                 sequences)
}

process RunInference {
    label 'predict'
    cpus 8
    memory "32 GB"
    accelerator 1, type: "nvidia-tesla-a10g"
    publishDir "/mnt/workflow/pubdir"

    input:
        path model
        path weights
        path sequences

    output:
        path "*.pdb", emit: results

    script:
    """
    set -ex

    export CUDA_VISIBLE_DEVICES=0
    export MODEL_PATH=./nim_model
    export WEIGHTS_DIRECTORY=/esm_models

    mkdir -p \$MODEL_PATH
    echo unpacking model from ${model} to \$MODEL_PATH
    tar xvf ${model} --directory \$MODEL_PATH

    # Unpack the model weights
    mkdir -p \$WEIGHTS_DIRECTORY
    echo unpacking weights from ${weights} to \$WEIGHTS_DIRECTORY
    tar xvf ${weights} --directory \$WEIGHTS_DIRECTORY

    # Start the NIMs
    /opt/nvidia/nvidia_entrypoint.sh supervisord -c /etc/supervisor/conf.d/supervisord.conf &
    NIMS_PID=\$!

    # Wait for NIMs to start
    sleep 120
    while [[ "\$(curl -s -o /dev/null -w ''%{http_code}'' localhost:8008/health/ready)" != "200" ]]; do sleep 5; done

    sleep 10

    for seq in `cat ${sequences}`
    do
        id=`echo \$seq | awk 'BEGIN{FS="zzzz"}{print \$1}'`
        chain=`echo \$seq | awk 'BEGIN{FS="zzzz"}{print \$2}'`

        echo \$id
        echo \$chain

        curl -X 'POST' \
        'http://localhost:8008/protein-structure/esmfold/predict' \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -d '{
            "sequence": "'\${chain}'"
        }' > \$id.json
        
        jq --raw-output '.pdbs[0]' < \$id.json > \$id.pdb
        sleep 1
    done

    sleep 10
    echo "shutting down NIMs"
    kill \$NIMS_PID
    sleep 5
    """

}
