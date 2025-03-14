nextflow.enable.dsl = 2

workflow EvoProtGrad {
    take:
    input_fasta
    plm_model_files
    plm_scorer_model_files
    plm_scorer_num_labels
    onehot_scorer_model_files
    preserved_regions
    output_type
    parallel_chains
    n_steps
    max_mutations

    main:
    Channel
        .fromPath(input_fasta)
        .splitFasta(record: [id: true, seqString: true])
        .set { wtseq_ch }
    
    RunDirectedEvolutionTask(
        wtseq_ch,
        plm_model_files,
        plm_scorer_model_files,
        plm_scorer_num_labels,
        onehot_scorer_model_files,
        preserved_regions,
        output_type,
        parallel_chains,
        n_steps,
        max_mutations
    )

    RunDirectedEvolutionTask.out.csvs
        .collect()
        .view { files -> println "[DEBUG] Collected CSV files for JSONL conversion: $files" }
        | CollectCSVtoJSONL
    
    CollectCSVtoJSONL.out.combined_jsonl
        .view { file -> println "[DEBUG] Created final JSONL file: ${file}" }
        .set { jsonl_ch }

    emit:
    jsonl_ch
}

process RunDirectedEvolutionTask {
    label 'evoprotgrad'
    cpus 4
    memory '16 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}", mode: 'copy', overwrite: 'false'
    tag "${wtseq_id}"  // Add tag for better logging

    input:
        tuple val(wtseq_id), val(wtseq)
        path plm_model_files
        path plm_scorer_model_files
        val plm_scorer_num_labels
        path onehot_scorer_model_files
        val preserved_regions
        val output_type
        val parallel_chains
        val n_steps
        val max_mutations
        
    output:
        path 'output/*.csv', emit: csvs

    script:
    def plm_arg = plm_model_files.name != 'null_plm' ? "--plm_expert_name_or_path=${plm_model_files}" : ''
    def plm_scorer_arg = plm_scorer_model_files.name != 'null_plm_scorer' ? "--plm_scorer_expert_name_or_path=${plm_scorer_model_files}" : ''
    def plm_scorer_num_labels_arg = plm_scorer_num_labels != 'null_plm_scorer_num_labels' ? "--plm_scorer_num_labels=${plm_scorer_num_labels}" : ''
    def onehot_scorer_arg = onehot_scorer_model_files.name != 'null_onehot_scorer' ? "--onehot_scorer_expert_name_or_path=${onehot_scorer_model_files}" : ''
    def preserved_regions_arg = preserved_regions != 'null_preserved_regions' ? "--preserved_regions='${preserved_regions}'" : ''   
   
    """
    set -euxo pipefail
    mkdir -p output
    /opt/conda/bin/python /home/scripts/directed_evolution.py ${wtseq} \
        ${wtseq_id} \
        output/ \
        ${plm_arg} \
        ${plm_scorer_arg} \
        ${plm_scorer_num_labels_arg} \
        ${onehot_scorer_arg} \
        ${preserved_regions_arg} \
        --output_type=${output_type} \
        --parallel_chains=${parallel_chains} \
        --n_steps=${n_steps} \
        --max_mutations=${max_mutations}
    """
}

process CollectCSVtoJSONL {
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}", mode: 'copy'
    
    input:
    path '*.csv'
    
    output:
    path 'main_result.jsonl', emit: combined_jsonl
    path 'experiment_result_index.json', emit: result_index

    script:
    """
    #!/bin/bash
    set -euo pipefail
    
    echo "[DEBUG] Starting CSV to JSONL conversion"
    echo "[DEBUG] Found CSV files: \$(ls *.csv)"
    
    # Get header from first CSV file and save it
    head -n1 \$(ls *.csv | head -n1) > header.txt
    
    # Create empty JSONL file
    > main_result.jsonl
    
    # Process each CSV file
    for csv in *.csv; do
        echo "[DEBUG] Processing file: \$csv"
        
        # Always skip the header line
        tail -n +2 "\$csv" | while IFS=, read -r line; do
            # Get header fields
            IFS=, read -r -a headers < header.txt
            
            # Read current line into array
            IFS=, read -r -a values <<< "\$line"
            
            # Start building JSON object
            json="{"
            
            # Combine headers with values
            for i in "\${!headers[@]}"; do
                # Clean up header and value
                header=\${headers[i]//\\\"/}
                header=\${header// /_}
                value=\${values[i]//\\\"/}
                
                # Add quotes around value
                if [[ \$i -eq 0 ]]; then
                    json="\${json}\\\"\${header}\\\":\\\"\${value}\\\""
                else
                    json="\${json},\\\"\${header}\\\":\\\"\${value}\\\""
                fi
            done
            
            # Close JSON object and append to file
            json="\${json}}"
            echo "\$json" >> main_result.jsonl
        done
    done
    
    # Count lines in output file
    total_lines=\$(wc -l < main_result.jsonl)
    echo "[DEBUG] Created JSONL file with \$total_lines lines"
    
    # Validate JSON format (optional)
    echo "[DEBUG] Validating JSONL format..."
    while IFS= read -r line; do
        if ! echo "\$line" | grep -q '^{.*}\$'; then
            echo "[ERROR] Invalid JSON line found: \$line"
            exit 1
        fi
    done < main_result.jsonl
    
    echo "[DEBUG] JSONL conversion completed successfully"
    echo "{"individual_result_map": {}, "zip_result": []}" | cat > experiment_result_index.json
    """
}

workflow {
    // Modify the Channel creation to handle null values
    def plm_model_ch = params.plm_model_files ? Channel.value(params.plm_model_files) : Channel.value(file('null_plm'))
    def plm_scorer_ch = params.plm_scorer_model_files ? Channel.value(params.plm_scorer_model_files) : Channel.value(file('null_plm_scorer'))
    def onehot_scorer_ch = params.onehot_scorer_model_files ? Channel.value(params.onehot_scorer_model_files) : Channel.value(file('null_onehot_scorer'))
    def plm_scorer_num_labels_ch = params.plm_scorer_num_labels ? Channel.value(params.plm_scorer_num_labels.toInteger()) : Channel.value('null_plm_scorer_num_labels')
    def preserved_regions = (params.preserved_regions && params.preserved_regions != 'None') ?  Channel.value(params.preserved_regions) : Channel.value('null_preserved_regions')

    EvoProtGrad(
        params.input_fasta,
        plm_model_ch,
        plm_scorer_ch,
        plm_scorer_num_labels_ch,
        onehot_scorer_ch,
        preserved_regions,
        Channel.value(params.output_type),
        Channel.value(params.parallel_chains),
        Channel.value(params.n_steps),
        Channel.value(params.max_mutations)
    )
}