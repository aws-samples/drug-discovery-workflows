#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include {
    ColabfoldSearch
} from '../colabfold-search/main'

include {
    Chai1
} from '../chai-1/main'

workflow PredictProteinComplexes {
    take:
        query
        use_msa
        use_templates
        constraints_path
        filter
        expand_eval
        align_eval
        diff
        qsc
        max_accept
        pairing_strategy
        db_load_mode
        unpack
        gpu_server
        recycle_msa_subsample
        num_trunk_recycles
        num_diffn_timesteps
        num_diffn_samples
        num_trunk_samples
        seed
        uniref30_db_path
        envdb_db_path
        pdb100_db_path
        pdb_snapshot_path
        chai1_parameters    

    main:

    is_complex = 1
    msa_directory = '/opt/scripts/NO_MSA'
    template_hits_path = '/opt/scripts/NO_TEMPLATE' 
    

    if(use_msa == 1 || use_templates == 1){

        ColabfoldSearch(
            query,
            uniref30_db_path,
            envdb_db_path,
            pdb100_db_path,
            is_complex,
            filter,
            expand_eval,
            align_eval,
            diff,
            qsc,
            max_accept,
            pairing_strategy,
            db_load_mode,
            unpack,
            gpu_server
        )

        if(use_msa == 1){
            ColabfoldSearch.out.msa.collect().set { msa_results }
            msa_results
                .map { file_paths -> 
                    def first_path = file_paths[0].toString()
                    return first_path.substring(0, first_path.lastIndexOf('/'))
                }
                .set { msa_directory }
        }
        if(use_templates == 1){
            ColabfoldSearch.out.template_hits.collect().set { template_hits_path }
        }
        else{
            pdb_snapshot_path = '/opt/scripts/NO_TEMPLATE' 
        }

    }
    else{
        pdb_snapshot_path = '/opt/scripts/NO_TEMPLATE' 
    }

    Chai1(
        query,
        msa_directory,
        template_hits_path,
        constraints_path,
        pdb_snapshot_path,
        chai1_parameters,
        recycle_msa_subsample,
        num_trunk_recycles,
        num_diffn_timesteps,
        num_diffn_samples,
        num_trunk_samples,
        seed
    )

    emit:
        Chai1.out
}


workflow {
    PredictProteinComplexes(
        params.query,
        params.use_msa,
        params.use_templates,
        params.constraints_path,
        params.filter,
        params.expand_eval,
        params.align_eval,
        params.diff,
        params.qsc,
        params.max_accept,
        params.pairing_strategy,
        params.db_load_mode,
        params.unpack,
        params.gpu_server,
        params.recycle_msa_subsample,
        params.num_trunk_recycles,
        params.num_diffn_timesteps,
        params.num_diffn_samples,
        params.num_trunk_samples,
        params.seed,
        params.uniref30_db_path,
        params.envdb_db_path,
        params.pdb100_db_path,
        params.pdb_snapshot_path,
        params.chai1_parameters,        
    )
}
