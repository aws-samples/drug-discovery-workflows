# RFDiffusion

This repository helps you set up and run RFDiffusion on AWS HealthOmics. Currently, this repository presents a "Hello World" scenario, which can be modified as needed for your specific use case.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

Much of this information (and much more!) can be found at the [RosettaCommons GitHub repository](https://github.com/RosettaCommons/RFdiffusion).

## Running a workflow

Pick your favorite small pdb file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that RFDiffusion likely will work best using `DYNAMIC` run storage due to low data volumes and faster startup times.

### Example params.json

Single file:

```json
{
    "input_pdb": "s3://mybucket/rfdiffusion/6cm4.pdb",
    "model_params":"s3://mybucket/rfdiffusion/model_parameters/",
    "container_image":"123456789012.dkr.ecr.us-east-1.amazonaws.com/rfdiffusion:latest"
}
```

With YAML based configuration file:

```json
{
    "input_pdb": "s3://mybucket/rfdiffusion/6cm4.pdb",
    "model_params":"s3://mybucket/rfdiffusion/model_parameters/",
    "container_image":"123456789012.dkr.ecr.us-east-1.amazonaws.com/rfdiffusion:latest",
    "yaml_file": "s3://mybucket/rfdiffusion/config.yaml"
}
```

Sample YAML: 
https://github.com/RosettaCommons/RFdiffusion/blob/b44206a2a79f219bb1a649ea50603a284c225050/config/inference/base.yaml

Be sure to set `contigmap.contigs` your desired value:

```yaml
contigmap:
  contigs: ["150-150"]
```

### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/rfdiffusion
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type DYNAMIC --parameters file://$PARAMS --name rfdiffusion
```

All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation

The original RFDiffusion paper can be found [here](https://www.biorxiv.org/content/10.1101/2022.12.09.519842v1).
