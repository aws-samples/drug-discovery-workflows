# DiffAb

This repository helps you set up and run DiffAb on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your favorite small fasta file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that DiffAb likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "input_pdb": "s3://my-bucket/diffab/7DK2_AB_C.pdb",
    "checkpoint_filename": "codesign_multicdrs.pt",
    "seed": 2022,
    "sample_structure": true,
    "sample_sequence": true,
    "cdrs": ["H_CDR1", "H_CDR2", "H_CDR3", "L_CDR1", "L_CDR2", "L_CDR3"],
    "num_samples": 100
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/diffab
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name diffab
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation
DiffAb was developed by Shitong Luo and Yufeng Su and Xingang Peng and Sheng Wang and Jian Peng and Jianzhu Ma. The original source code can be found [here](https://github.com/luost26/diffab). The algorithm is presented in the following papers.

https://www.biorxiv.org/content/10.1101/2022.07.10.499510v5.abstract

```
@inproceedings{luo2022antigenspecific,
  title={Antigen-Specific Antibody Design and Optimization with Diffusion-Based Generative Models for Protein Structures},
  author={Shitong Luo and Yufeng Su and Xingang Peng and Sheng Wang and Jian Peng and Jianzhu Ma},
  booktitle={Advances in Neural Information Processing Systems},
  editor={Alice H. Oh and Alekh Agarwal and Danielle Belgrave and Kyunghyun Cho},
  year={2022},
  url={https://openreview.net/forum?id=jSorGn2Tjg}
}
```

