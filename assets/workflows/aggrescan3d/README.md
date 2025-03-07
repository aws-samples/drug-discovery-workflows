# Aggrescan3D

This repository helps you set up and run Aggrescan3D on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your CSV file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that Aggrescan3D likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "input_pdb": "s3://my-bucket/aggrescan3d/example.pdb"
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/aggrescan3d
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name aggrescan3d
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

### License Information

If enabling Dynamic mode, you may encounter an error with the `modeller` dependency of CABSFlex. It requires a license, see:

https://bitbucket.org/lcbio/cabsflex/src/master/README.md
https://salilab.org/modeller/10.6/release.html#anaconda

for more information. The `modeller` installation is currently commented out in the [`Dockerfile`](../../containers/aggrescan3d/Dockerfile) to avoid this issue.

## Citation
Aggrescan3D was developed by developed by the Laboratory of Computational Biology at University of Warsaw in cooperation with the Laboratory of Protein Folding and Conformational Diseases at Univesity of Barcelona. The original source code can be found [here](https://bitbucket.org/lcbio/aggrescan3d).

