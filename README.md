# Drug Discovery Workflows for AWS HealthOmics

## Description

A collection of AWS HealthOmics workflows to accelerate drug discovery.

## Deployment

For individual deployments, you also can navigate to the README in `workflows/<workflow-name>`.

### Quick Start

1. Clone this repository to your local environment.
2. Authenticate into your AWS account of interest and `cd` into the project dir.
3. Run the following command, replacing the placeholders with the name of a S3 bucket,
desired stack name, and region:

```bash
./deploy.sh \
  -b "my-deployment-bucket" \
  -n "my-aho-ddw-stack" \
  -r "us-east-1"
```

The CloudFormation deployment and asset build steps should finish in about 15 minutes. Once the deployment has finished, you can create a private workflow run using the Amazon HealthOmics console, CLI, or SDK.

## Development

To add a new module add the necessary files to the `assets` folder. There are three main components:

* **Containers:** contains Dockerfiles and supporting files required to run workflow tasks.
* **Data:** contains links to parameters and other reference data used by workflow models
* **Workflows:** Specifc workflows, such as AlphaFold-Multimer that contain the `main.nf` script.

```txt
assets/
└──containers/
    ├── alphafold
    ├── biolambda
    └── ...
    data/
    ├── alphafold2/
    ├── alphafold-multimer/
    ├── unpack.nf
    └── ...
    workflows/
    ├── alphafold2/
    ├── alphafold-multimer/
    └── ...
```

The `containers` folder contains Dockerfiles and supporting files to build docker containers. The deployment process will attempt to use every subfolder here as a Docker build context without any further configuration. Right now, there are two types of containers provided by default.

The `data` folder contains `.txt` files that specify uris to download during stack creation. The deployment workflow will save the contents of each file in the following S3 locations:

`s3:<BUCKET NAME SPECIFIED IN CFN>/ref-data/<FILENAME WITHOUT EXTENSION>/...`

We currently support three types of data sources:

- s3: Records that begin with `s3` will be downloaded using the AWS CLI.
- HuggingFace Hub: Records that look like the canonical `organization/project` HuggingFace ID will be cloned, packaged into a .tar file, and copied to s3 using a mountpoint.
- Other: All other records will be downloaded using `wget` to an s3 mountpoint.

The `workflows` contains the HeathOmics workflow files (.wdl and .nf) and supporting files to create private workflows. The deployment process will attempt to deploy every subfolder here as a HealthOmics workflow deployment package without any further configuration. Just drop in your modules and deploy! To reference a private docker image in your workflow files, replace the uri with a {{MyContainer}} placeholder, where "MyContainer" is the name of your repository. For containers you define in the `modules/containers` folder, this will be the folder name. The deployment pipeline will automatically replace the placeholder with the correct ECR URI for your account and region. For example, if you want to use the "biolambda" container, use {{biolambda}}. You can also append an image tag, like {{biolambda:latest}}. You can also reference your deployment S3 bucket with {{S3_BUCKET_NAME}} to access data downloaded during stack creation.
