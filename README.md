# Drug Discovery Workflows for AWS HealthOmics

## Description

A collection of AWS HealthOmics workflows to accelerate drug discovery.

## Workflow Catalog

### Modules

- [ABodyBuilder3](https://github.com/Exscientia/abodybuilder3): From Exscientia. Predict the 3D structure of antibody heavy and light chains.
- [Alphafold2-Monomer](https://github.com/aws-samples/drug-discovery-workflows/tree/main/assets/workflows/alphafold2-monomer): From Google DeepMind. Predict the 3D structure of one or more single-chain proteins
- [Alphafold2-Multimer](https://github.com/aws-samples/drug-discovery-workflows/tree/main/assets/workflows/alphafold2-multimer): From Google DeepMind. Predict the 3D structure of multi-chain protein complexes.
- [AlphaBind](https://github.com/A-Alpha-Bio/alphabind): From A-Alpha Bio. Predict and optimize antibodu-antigen binding affinity.
- [AMPLIFY Pseudo Perplexity](https://github.com/chandar-lab/AMPLIFY): From Amgen and Mila. Calculate the pseudoperplexity of an amino acid sequence using a protein language model.
- [Chai-1](https://github.com/chaidiscovery/chai-lab): From Chai Discovery. Predict the structure of biomolecule complexes including proteins, amino acids, and/or ligands.
- [BioNeMo NiM Protein Design](https://docs.nvidia.com/nim/#bionemo) Use BioNeMo NiM containers to design proteins using RFDifusion, ProteinMPNN, and AlphaFold-Multimer.
- [ESMfold](https://github.com/aws-samples/drug-discovery-workflows/tree/main/assets/workflows/esmfold): From Meta. Rapidly predict protein structures using embeddings geneted by the ESM2 protein language model.
- [EvoProtGrad](https://github.com/NREL/EvoProtGrad): From NREL. Directed evolution on a protein sequence with gradient-based discrete Markov chain monte carlo (MCMC).
- [Generate Protein Sequence Embeddings](https://github.com/aws-samples/drug-discovery-workflows/tree/main/assets/workflows/generate-protein-seq-embeddings):  From Meta. Generate ESM-2 vector embeddings for one or more protein amino acid sequences.
- [NanobodyBuilder2](https://github.com/oxpig/ImmuneBuilder): From Oxford Protein Informatics Group. Predict the 3D structure of single-chain nanobodies.
- [RFDiffusion-ProteinMPNN](https://github.com/aws-samples/drug-discovery-workflows/tree/main/assets/workflows/rfdiffusion-proteinmpnn): From the Institute for Protein Design at the University of Washington. Generate protein backbone structures and sequences given a binding target or other structural context.
- [ThermoMPNN](https://github.com/Kuhlman-Lab/ThermoMPNN): From the University of North Carolina School of Medicine. Predict changes in thermodynamic stability for protein point mutants.

### E2E Workflows

- [Design Nanobodies](https://github.com/aws-samples/drug-discovery-workflows/tree/main/assets/workflows/design-nanobodies): Generate de novo nanobody candidates against a given target protein structure and epitope using RFDiffusion, ProteinMPNN, ESMFold, AMPLIFY, and NanobodyBuilder2.

## Deployment

This repository contains Amazon CloudFormation templates and supporting resources to automatically deploy AWS HealthOmics private workflows into your AWS account. You are responsible for all costs associated with the deployed resources.

### Quick Start

1. Clone this repository to your local environment.
2. Authenticate into your AWS account of interest and `cd` into the project dir.
3. Run the following command, replacing the placeholders with the name of a S3 bucket, desired stack name, and region:

```bash
bash scripts/deploy.sh \
  -b "my-deployment-bucket" \
  -n "my-aho-ddw-stack" \
  -r "us-east-1"
```

The CloudFormation deployment and asset build steps should finish in about 15 minutes. Once the deployment has finished, you can create a private workflow run using the Amazon HealthOmics console, CLI, or SDK.

Once the deployment has finished, you can create a private workflow run using the Amazon HealthOmics console, CLI, or SDK. You may re-run the `./deploy.sh` script with the same arguments to update the CloudFormation stacks after code modifications to NextFlow scripts, Dockerfiles, or container build context directories are saved. This will trigger a rebuild and push of containers to ECR with the `latest` tag, and create new versions of the HealthOmics workflows.

To add a new module add the necessary files to the `assets` folder. There are three main components:

Many of the workflows in this repository require additional model weights or reference data. Please refer to the README files for each workflow in the `workflows/` folder.

## Third Party Credentials

Follow these steps to download data from third-party repositories:

1. Obtain an API key or other credential with the necessary access to the data.
2. Save the credentials in AWS Secrets Manager, for example:

```bash
aws secretsmanager create-secret \
    --name MyDataCredentials \
    --description "My data credentials." \
    --secret-string "{\"API_KEY\":\"MyFakeKey\",\"ORG\":\"myfakeorg\"}"
```

3. Add your data uri to a new file in the `assets/data` folder.
4. Run the deploy.sh script with the `-s` option and pass in your secret name (not the key or value) from step 1. CodeBuild will save these secret values as environment variables in the data download job.

### Infrastructure Diagram

<img src="./img/infra-diagram.png" />

## Development

To add a new module, fork the repository. There are three main components:

* **Containers:** contains the required information/data to build Docker images for specific tasks
* **Data:** contains links to parameters and other reference data used by workflow models
* **Workflows:** Specifc workflows, such as AlphaFold-Multimer that contain the `main.nf` script.

```txt
assets/
└──containers/
    ├── alphafold
    ├── biolambda
    └── ...
    data/
    ├── esm2.txt
    ├── esmfold.txt
    ├── rfdiffusion.txt
    └── ...
    workflows/
    ├── alphafold2/
    ├── alphafold-multimer/
    └── ...
```

The `containers` folder contains Dockerfiles and supporting files to build docker containers. The deployment process will attempt to use every subfolder here as a Docker build context without any further configuration. Right now, there are two types of containers provided by default.

The `data` folder contains `.txt` files that specify uris to download during stack creation. The deployment workflow will save the contents of each file in the following S3 locations:

### Linting

You can lint this repositories NextFlow code using the AWS provided tool [awslabs/linter-rules-for-nextflow](https://github.com/awslabs/linter-rules-for-nextflow), which has been been integrated with `make`:

```bash
make lint
```

Also see [.github/workflows](./.github/workflows/) for other linting tools that have been setup as GitHub Actions workflows.

### Development Test Script

The `scripts/testrun.sh` script can be used to invoke NextFlow workflows in this repository, for development purposes, with the specified param json file. Be sure to create a file with your desired input params, for which the Omics exeution role has S3 access.

Prerequisites:

* S3 bucket with input data
* S3 bucket to store outputs, can be the same as the input bucket
* HealthOmics execution role with access to the buckets `testparams/rfdiffusion.params.json`:

```sh
{
  "input_pdb": "s3://mybucket/rfdiffusion/6cm4.pdb"
}
```

Example run with full argument list:

```sh
./scripts/testrun.sh \
-w rfdiffusion \
-a 123456789012 \
-r us-east-1 \
-o "arn:aws:iam::123456789012:role/healthomics-dev-role" \
-b mybucket \
-p file://testparams/rfdiffusion.params.json
```

Or create an `.aws/env` file to simplify the arguments:

```sh
ACCOUNT_ID=123456789012
REGION=us-east-1
OMICS_EXECUTION_ROLE=arn:aws:iam::123456789012:role/healthomics-dev-role
OUTPUT_BUCKET=mybucket
```

and then:

```sh
./scripts/testrun.sh -w rfdiffusion -p testparams/rfdiffusion.params.json
```

`s3:<BUCKET NAME SPECIFIED IN CFN>/ref-data/<FILENAME WITHOUT EXTENSION>/...`

We currently support three types of data sources:

* s3: Records that begin with `s3` will be downloaded using the AWS CLI.
* HuggingFace Hub: Records that look like the canonical `organization/project` HuggingFace ID will be cloned, packaged into a .tar file, and copied to s3 using a mountpoint.
* NVIDIA NGC: Records that begin with `nvidia` will be downloaded using the NCG CLI IF credentials are provided via the `-s` option in `delpoy.sh`.
* Other: All other records will be downloaded using `wget` to an s3 mountpoint.

The `workflows` contains the HeathOmics workflow files (.wdl and .nf) and supporting files to create private workflows. The deployment process will attempt to deploy every subfolder here as a HealthOmics workflow deployment package without any further configuration. Just drop in your modules and deploy! To reference a private docker image in your workflow files, replace the uri with a {{MyContainer}} placeholder, where "MyContainer" is the name of your repository. For containers you define in the `modules/containers` folder, this will be the folder name. The deployment pipeline will automatically replace the placeholder with the correct ECR URI for your account and region. For example, if you want to use the "biolambda" container, use {{biolambda}}. You can also append an image tag, like {{biolambda:latest}}. You can also reference your deployment S3 bucket with {{S3_BUCKET_NAME}} to access data downloaded during stack creation.
