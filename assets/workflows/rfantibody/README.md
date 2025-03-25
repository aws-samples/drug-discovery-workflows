# RFantibody

This repository helps you set up and run RFantibody on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your target_pdb and framework_pdb files to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that RFantibody likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "target_pdb": "s3://my-bucket/rfantibody/rsv_site3.pdb",
    "framework_pdb": "s3://my-bucket/rfantibody/1fvc_chothia.pdb",
    "hotspot_res": "[T305,T456]",
    "design_loops": "[L1:8-13,L2:7,L3:9-11,H1:7,H2:6,H3:5-13]",
    "num_designs": 5,
    "is_hlt": false,
    "heavy_chain_id": "B",
    "light_chain_id": "A"
}
```

When `is_hlt` is set to `false`, the pipeline will convert the input PDBs to HLT format. This is useful when the input PDBs are not in HLT format. The `heavy_chain_id` and `light_chain_id` are the chain IDs of the heavy and light chains in the input PDBs to be converted. `target_chains` is a comma-separated list of chain IDs in the target PDB that the pipeline will design against.

### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/rfantibody
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name rfantibody
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation

RFantibody was developed by Nathaniel Bennett. The original source code can be found [here](https://github.com/RosettaCommons/RFantibody). The pipeline is presented in the following papers.

```
@article {Bennett2024.03.14.585103,
	author = {Bennett, Nathaniel R. and Watson, Joseph L. and Ragotte, Robert J. and Borst, Andrew J. and See, D{\'e}jena{\'e} L. and Weidle, Connor and Biswas, Riti and Shrock, Ellen L. and Leung, Philip J. Y. and Huang, Buwei and Goreshnik, Inna and Ault, Russell and Carr, Kenneth D. and Singer, Benedikt and Criswell, Cameron and Vafeados, Dionne and Garcia Sanchez, Mariana and Kim, Ho Min and V{\'a}zquez Torres, Susana and Chan, Sidney and Baker, David},
	title = {Atomically accurate de novo design of single-domain antibodies},
	elocation-id = {2024.03.14.585103},
	year = {2024},
	doi = {10.1101/2024.03.14.585103},
	publisher = {Cold Spring Harbor Laboratory},
	abstract = {Despite the central role that antibodies play in modern medicine, there is currently no way to rationally design novel antibodies to bind a specific epitope on a target. Instead, antibody discovery currently involves time-consuming immunization of an animal or library screening approaches. Here we demonstrate that a fine-tuned RFdiffusion network is capable of designing de novo antibody variable heavy chains (VHH{\textquoteright}s) that bind user-specified epitopes. We experimentally confirm binders to four disease-relevant epitopes, and the cryo-EM structure of a designed VHH bound to influenza hemagglutinin is nearly identical to the design model both in the configuration of the CDR loops and the overall binding pose.Competing Interest StatementN.R.B., J.L.W., R.J.R., A.J.B., C.W., P.J.Y.L., B.H., and D.B. are co-inventors on U.S. provisional patent number 63/607,651 which covers the computational antibody design pipeline described here.},
	URL = {https://www.biorxiv.org/content/early/2024/03/18/2024.03.14.585103},
	eprint = {https://www.biorxiv.org/content/early/2024/03/18/2024.03.14.585103.full.pdf},
	journal = {bioRxiv}
}
```
