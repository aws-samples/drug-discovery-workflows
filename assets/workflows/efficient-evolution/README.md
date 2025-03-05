# Efficient Evolution 

This repository helps you set up and run Efficient Evolution on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your favorite pdb file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that Efficient Evolution likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "sequence_fasta": "s3://my-bucket/efficient-evolution/sequence.fasta"
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/efficient-evolution
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name efficient-evolution
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation
Efficient Evolution was developed by Brian Hie and Yufeng Su and Jon Burvill. The original source code can be found [here](https://github.com/brianhie/efficient-evolution). The algorithm is presented in the following papers.

https://www.nature.com/articles/s41587-023-01763-2
