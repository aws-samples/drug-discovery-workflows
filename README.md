# Drug Discovery Workflows for Amazon HealthOmics

## Description

A collection of Amazon HealthOmics workflows to accelerate drug discovery.

## News

Amazon HealthOmics Drug Discovery Workflows now supports the [ESM3](https://huggingface.co/EvolutionaryScale/esm3-sm-open-v1) model by [EvolutionaryScale](https://www.evolutionaryscale.ai/)! Please see the `README` file at `workflows/protein_annotation/` for more information.

## Deployment

For individual deployments, you also can navigate to the README in `workflows/<workflow-name>`. The following is currently a WIP, but will be the recommended way shortly!

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

The CloudFormation deployment should finish in about 3 minutes. It will take another 30 minutes to build the algorithm containers.

Once the deployment has finished, you can create a private workflow run using the Amazon HealthOmics console, CLI, or SDK.

### Data

Many of the workflows in this repository require additional model weights or reference data. Please refer to the README files for each workflow in the `workflows/` folder.

## Development (WIP)

To add a new module, fork the repository. There are three main components:

* **Containers:** contains the required information/data to build Docker images for specific tasks
* **Modules:** common packages, such as MSA search/unpacking data that multiple algorithms may use
* **Workflows:** Specifc workflows, such as AlphaFold-Multimer that contain the `main.nf` script.

```txt
containers/
├── alphafold
├── biolambda
└── ...
modules/
├── alphafold2/
├── alphafold-multimer/
├── unpack.nf
└── ...
workflows/
├── alphafold2/
├── alphafold-multimer/
└── ...
```

The `containers` folder contains Dockerfiles and supporting files to build docker containers. The deployment process will attempt to use every subfolder here as a Docker build context without any further configuration. Right now, there are two types of containers provided by default. "Framework" containers like "biolambda" and "transformers" provide general-purpose ML environments to run custom scripts (passed in during container build via the "scripts" folder). "Algorithm" containers like "alphafold", on the other hand, contain dependencies and scripts for spoecific models, in many cases lightly adapted from open source repositories. These are meant to be used as-is, without much customization.

Similarly, the `workflows` contains the HeathOmics workflow files (.wdl and .nf) and supporting files to create private workflows. The deployment process will attempt to deploy every subfolder here as a HealthOmics workflow deployment package without any further configuration. Just drop in your modules and deploy! To reference a private docker image in your workflow files, replace the uri with a {{MyContainer}} placeholder, where "MyContainer" is the name of your repository. For containers you define in the `modules/containers` folder, this will be the folder name. The deployment pipeline will automatically replace the placeholder with the correct ECR URI for your account and region. For example, if you want to use the "biolambda" container, use {{biolambda}}. You can also append an image tag, like {{biolambda:latest}}.
