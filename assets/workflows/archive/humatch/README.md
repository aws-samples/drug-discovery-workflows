# Humatch

This repository helps you set up and run Humatch on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your CSV file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that Humatch likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "input_csv": "s3://my-bucket/humatch/example.csv"
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/humatch
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name humatch
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation
Humatch was developed by Lewis Chinery. The original source code can be found [here](https://github.com/lewis-chinery/Humatch). The algorithm is presented in the following papers.

```
@article{Chinery2024,
  title = {Humatch - fast, gene-specific joint humanisation of antibody heavy and light chains},
  author = {Lewis Chinery, Jeliazko R Jeliazkov, and Charlotte M Deane},
  journal = {bioRxiv},
  year = {2024},
  doi = {10.1101/2024.09.16.613210}
}
```
