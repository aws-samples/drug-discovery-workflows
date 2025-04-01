# ANTIPASTI

This repository helps you set up and run ANTIPASTI on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your favorite pdb file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that ANTIPASTI likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "input_pdb": "s3://my-bucket/antipasti/8hn7.pdb"
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/antipasti
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name antipasti
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation

ANTIPASTI was developed by Kevin Michalewicz, Mauricio Barahona and Barbara Bravi. The original source code can be found [here](https://github.com/kevinmicha/ANTIPASTI). The algorithm is presented in the following papers.

https://doi.org/10.1016/j.str.2024.10.001

```
@article{MICHALEWICZ20242422,
title = {ANTIPASTI: Interpretable prediction of antibody binding affinity exploiting normal modes and deep learning},
journal = {Structure},
volume = {32},
number = {12},
pages = {2422-2434.e5},
year = {2024},
issn = {0969-2126},
doi = {https://doi.org/10.1016/j.str.2024.10.001},
url = {https://www.sciencedirect.com/science/article/pii/S0969212624004362},
author = {Kevin Michalewicz and Mauricio Barahona and Barbara Bravi},
keywords = {antibody, binding affinity, deep learning, interpretability, normal mode analysis, protein structures},
abstract = {Summary
The high binding affinity of antibodies toward their cognate targets is key to eliciting effective immune responses, as well as to the use of antibodies as research and therapeutic tools. Here, we propose ANTIPASTI, a convolutional neural network model that achieves state-of-the-art performance in the prediction of antibody binding affinity using as input a representation of antibody-antigen structures in terms of normal mode correlation maps derived from elastic network models. This representation captures not only structural features but energetic patterns of local and global residue fluctuations. The learnt representations are interpretable: they reveal similarities of binding patterns among antibodies targeting the same antigen type, and can be used to quantify the importance of antibody regions contributing to binding affinity. Our results show the importance of the antigen imprint in the normal mode landscape, and the dominance of cooperative effects and long-range correlations between antibody regions to determine binding affinity.}
}
```
