# NVIDIA Generative Virtual Screening Blueprint on AWS HealthOmics

This repository helps you set up and run [NVIDIA Inference Microservices (NIMs) Agent Blueprint](https://github.com/NVIDIA-NIM-Agent-Blueprints/generative-virtual-screening/tree/main) on AWS HealthOmics for generative virtual screening. Currently, this repository presents an example, which can be modified as needed for your specific use case.

The following setup steps below assume you have basic understanding on [NVIDIA BioNeMo NIMs](https://docs.nvidia.com/nim/#bionemo) and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

Much of this information (and much more!) can be found at https://github.com/NVIDIA-NIM-Agent-Blueprints/generative-virtual-screening/

## Getting Started

### Step 1: Set up ECR and Push NIM containers

1. There three containers used: `molmim`, `alphafold2`, and `diffdock` in ECR. Feel free to use your preferred method of choice to create the ECR respositories (e.g. using AWS-owned keys for encryption) and set the [appropriate policies](https://docs.aws.amazon.com/omics/latest/dev/workflows-ecr.html#permissions-ecr). 

2. Create an g5.xlarge EC2 instance with S3 and ECR permissions of the [instance profile IAM role](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html). 

3. Create a NGC account and [generate an API key](https://org.ngc.nvidia.com/setup/api-key) to download NIM containers

4. Login EC2 instance, setup environment varialble `NGC_API_KEY`, and Docker log in with your NGC API key, like `docker login nvcr.io --username='$oauthtoken' --password=${NGC_API_KEY}`

5. Docker pull NIM container images for [molmim](https://docs.nvidia.com/nim/bionemo/molmim/latest/quickstart-guide.html), [alphafold2](https://docs.nvidia.com/nim/bionemo/alphafold2/latest/quickstart-guide.html), [diffdock](https://docs.nvidia.com/nim/bionemo/diffdock/latest/getting-started.html). Then [Login ECR using command line](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html), [tag the downloaded NIM containers](https://docs.docker.com/reference/cli/docker/image/tag/) and push them to ECR. You will use the ECR image URIs to configure `nextflow.config` file.


### Step 2: Upload Files to S3

Create the following S3 buckets and folders:
* `s3://{mybucket}/molmim/`
* `s3://{mybucket}/molmim/input/`
* `s3://{mybucket}/alphafold2/`
* `s3://{mybucket}/alphafold2/input/`
* `s3://{mybucket}/diffdock/`
* `s3://{mybucket}/nim/scripts/`
* `s3://{mybucket}/nim/output/`

First upload python scripts (in `scripts` folder) to run inside NIM containers, including `molmim_generate.py`, `alphafold2_predict.py`, and `run_diffdock.py` to S3 path `s3://{mybucket}/nim/scripts/`. 

Secondly, upload sample SMILES and FASTA files in the `input` folder to s3:
* `s3://{mybucket}/molmim/input/sampleinput.smi`
* `s3://{mybucket}/alphafold2/input/mysequence.fasta`

Lastly, upload the model weights to S3. Run your NIM containers on EC2 instance following the quickstart instructions one-by-one: [molmim](https://docs.nvidia.com/nim/bionemo/molmim/latest/quickstart-guide.html), [alphafold2](https://docs.nvidia.com/nim/bionemo/alphafold2/latest/quickstart-guide.html), and [diffdock](https://docs.nvidia.com/nim/bionemo/diffdock/latest/getting-started.html). During the container runtime, each container will first download the model weights to a predefined path, set up by a container environment variable `NIM_CACHE_PATH`. You can login each container using command line like `docker exec -u root -it <containerid> sh`, [download and install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), and go to `NIM_CACHE_PATH` folder and sync the local model weights inside the container to the s3 paths created earlier. You S3 model weights should looks like:
* `s3://{mybucket}/molmim/models/molmim_v1.3/`
* `s3://{mybucket}/alphafold2/alphafold2-data_v1.0.0/`
* `s3://{mybucket}/diffdock/models/bionemo-diffdock_v1.2.0/`

```
BUCKET=mybucket

aws s3 sync ${NIM_CACHE_PATH}/models/ s3://${BUCKET}/${MODEL_PREFIX}/
```

### Step 3: Update Nextflow config with S3 and ECR information

Now let's create the workflow. In HealthOmics, this is as simple as creating a zip file and uploading the workflow. Before we do that, though, let's modify the `nextflow.config` and `params.json` to make sure the right files and containers are referenced. Make sure the `{mybucket}` and ECR repos are mapping to your account specific information.


### Step 4: Create Workflow

You can now zip and create your workflow. Do the following via the command line terminal where you have clone the code repo. Since this repository contains multiple workflows, you want to set your main entry to `definition/main.nf`. Before deploying, go to this folder: `cd drug-discovery-workflows/workflows/virtual-screening-blueprint`

```
rm definition.zip
zip -r ../definition.zip definition/

aws omics create-workflow --engine NEXTFLOW --definition-zip fileb://./definition.zip --main definition/main.nf --name nim-blueprint --parameter-template file://./definition/parameter-template.json
```

Note the workflow ID you get in the response and use it to set up `WFID` in next step.

### Step 5: Run a workflow
The following command can be done from the terminal or you can navigate to the AWS console. 
Create an IAM role to run HealthOmics jobs, and set up value of `$ROLEARN` to this role ARN. Replace `$OUTPUTLOC` with the S3 folder created earlier `s3://{mybucket}/nim/output/`. Also modify the `params.json` to point to your SMILES and FASTA files.

```
WFID=
ROLEARN=
OUTPUTLOC=s3://{mybucket}/nim/output/
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --parameters file://definition/params.json --name nim-blueprint
```

All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.


