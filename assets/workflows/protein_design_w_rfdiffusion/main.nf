nextflow.enable.dsl = 2

// static data files are in nextflow.config
workflow {
    RunInference(
                 params.input_pdb,
                 params.config_file,
                 params.base_ckpt,
                 params.complex_base_ckpt,
                 params.complex_Fold_base_ckpt,
                 params.inpaintSeq_ckpt,
                 params.inpaintSeq_Fold_ckpt,
                 params.activeSite_ckpt,
                 params.base_epoch8_ckpt,
                 params.complex_beta_ckpt
                 )
}

// Configuration options
// https://github.com/RosettaCommons/RFdiffusion/blob/main/config/inference/base.yaml

process RunInference {
    label 'predict'
    cpus 8
    memory '32 GB'
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir '/mnt/workflow/pubdir'

    input:
        path input_pdb
        path config_file
        path base_ckpt
        path complex_base_ckpt
        path complex_Fold_base_ckpt
        path inpaintSeq_ckpt
        path inpaintSeq_Fold_ckpt
        path activeSite_ckpt
        path base_epoch8_ckpt
        path complex_beta_ckpt

    output:
        path 'output/*', emit: results

    script:
    """
    set -euxo pipefail
    mkdir output model config
    export HYDRA_FULL_ERROR=1

    cp ${config_file} config
    cp ${base_ckpt} ${complex_base_ckpt} \
      ${complex_Fold_base_ckpt} ${inpaintSeq_ckpt} \
      ${inpaintSeq_Fold_ckpt} ${activeSite_ckpt} \
      ${base_epoch8_ckpt} ${complex_beta_ckpt} model

    /opt/conda/bin/python3 /opt/module/scripts/run_inference.py \
        --config-dir config \
        --config-name ${config_file.baseName} \
        inference.output_prefix=output/rfdiffusion \
        inference.model_directory_path=model \
        inference.input_pdb=${input_pdb}
    """
}
