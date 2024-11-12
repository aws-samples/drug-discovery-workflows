# OpenFold

This repository helps you set up and run OpenFold Monomer inference on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

Much of this information (and much more!) can be found at the [OpenFold documentation site](https://openfold.readthedocs.io/).

## Running a workflow

Pick your favorite small fasta file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that OpenFold likely will work best using `DYNAMIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "fasta_dir": "s3://my-input-bucket/openfold/fasta/"
}
```

### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/openfold
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type DYNAMIC --parameters file://$PARAMS --name openfold
```

All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation

The original OpenFold paper can be found [here](https://www.biorxiv.org/content/10.1101/2022.11.20.517210v1).
