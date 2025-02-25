# PEP-Patch (surface_analyses)

This repository helps you set up and run PEP-Patch on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your CSV file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that PEP-Patch likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "electrostatic_parm": "s3://my-bucket/pep-patch/trastuzumab/apbs-input.pdb",
    "electrostatic_crd": "s3://my-bucket/pep-patch/trastuzumab/apbs-potential.dx",

    "hydrophobicity_parm": "s3://my-bucket/pep-patch/1csa-model1.pdb",
    "hydrophobicity_crd": "s3://my-bucket/pep-patch/1csa-model1.dup.pdb",
    "scale": "rdkit-crippen",
    "smiles": "CCC1C(=O)N(CC(=O)N(C(C(=O)NC(C(=O)N(C(C(=O)NC(C(=O)NC(C(=O)N(C(C(=O)N(C(C(=O)N(C(C(=O)N(C(C(=O)N1)C(C(C)CC=CC)O)C)C(C)C)C)CC(C)C)C)CC(C)C)C)C)C)CC(C)C)C)C(C)C)CC(C)C)C)C"
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/pep-patch
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name pep-patch
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation

PEP-Patch was developed by Franz Waibl. The original source code can be found [here](https://github.com/liedllab/surface_analyses). The algorithm is presented in the following papers.

```
@article{Hoerschinger2023,
author = {Hoerschinger, Valentin J. and Waibl, Franz and Pomarici, Nancy D. and Loeffler, Johannes R. and Deane, Charlotte M. and Georges, Guy and Kettenberger, Hubert and Fernández-Quintero, Monica L. and Liedl, Klaus R.},
title = {PEP-Patch: Electrostatics in Protein–Protein Recognition, Specificity, and Antibody Developability},
journal = {Journal of Chemical Information and Modeling},
volume = {63},
number = {22},
pages = {6964-6971},
year = {2023},
doi = {10.1021/acs.jcim.3c01490},
}
```
