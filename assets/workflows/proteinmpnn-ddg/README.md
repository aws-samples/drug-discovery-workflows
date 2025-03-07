# ProteinMPNN-ddG

This repository helps you set up and run ProteinMPNN-ddG on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your CSV file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that ProteinMPNN-ddG likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "input_pdb": "s3://my_bucket/proteinmpnn-ddg/example.pdb"
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/proteinmpnn-ddg
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name proteinmpnn-ddg
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation
ProteinMPNN-ddG was developed by Dutton, Oliver and Bottaro, Sandro and Invernizzi, Michele and Redl, Istvan and Chung, Albert and Fisicaro, Carlo and Airoldi, Fabio and Ruschetta, Stefano and Henderson, Louie and Owens, Benjamin MJ and Foerch, Patrik and Tamiola, Kamil. The original source code can be found [here](https://github.com/PeptoneLtd/proteinmpnn_ddg). The algorithm is presented in the following papers.

```
@inproceedings{proteinmpnn_ddg,
  title     = {Improving Inverse Folding models at Protein Stability Prediction without additional Training or Data},
  author    = {Dutton, Oliver and Bottaro, Sandro and Invernizzi, Michele and Redl, Istvan and Chung, Albert and Fisicaro, Carlo and Airoldi, Fabio and Ruschetta, Stefano and Henderson, Louie and Owens, Benjamin MJ and Foerch, Patrik and Tamiola, Kamil},
  booktitle = {Proceedings of the NeurIPS Workshop on Machine Learning in Structural Biology},
  year      = {2024},
  note      = {Workshop Paper},
  url       = {https://www.mlsb.io/papers_2024/Improving_Inverse_Folding_models_at_Protein_Stability_Prediction_without_additional_Training_or_Data.pdf}
}
```
