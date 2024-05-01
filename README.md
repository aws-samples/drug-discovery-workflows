# Drug Discovery Workflows for Amazon HealthOmics

## Description

A collection of Amazon HealthOmics workflows to accelerate drug discovery.

## Deployment

### Quick Start

1. Choose **Launch Stack** and (if prompted) log into your AWS account:

    [![Launch Stack](img/LaunchStack.jpg)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://aws-hcls-ml.s3.amazonaws.com/build/main/packaged.yaml)  
2. For **Stack Name**, enter a value unique to your account and region. Leave the other parameters as their default values and select **Next**.  
3. Select **I acknowledge that AWS CloudFormation might create IAM resources with custom names**.  
4. Choose **Create stack**.  
    ![Choose Create Stack](img/create_stack.png)  
5. Wait 30 minutes for AWS CloudFormation to create the necessary infrastructure stack and module containers.
6. Once the deployment has finished, you can view your private workflows from the Amazon HealthOmics Workflows console.

### Custom Deployment

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

## Development

To add a new module, clone the repository and take a look at the `modules` folder.

```txt
modules/
├── containers
│   ├── alphafold
│   ├── biolambda
│   └── ...
└── workflows
    └── esm2_embeddings
    └── esmfold
    └── ...
```

The `containers` folder contains Dockerfiles and supporting files to build docker containers. The deployment process will attempt to use every subfolder here as a Docker build context without any further configuration. Right now, there are two types of containers provided by default. "Framework" containers like "biolambda" and "transformers" provide general-purpose ML environments to run custom scripts (passed in during container build via the "scripts" folder). "Algorithm" containers like "alphafold", on the other hand, contain dependencies and scripts for spoecific models, in many cases lightly adapted from open source repositories. These are meant to be used as-is, without much customization.

Similarly, thr `workflows` contains the HeathOmics workflow files (.wdl and .nf) and supporting files to create private workflows. The deployment process will attempt to deploy every subfolder here as a HealthOmics workflow deployment package without any further configuration. Just drop in your modules and deploy! To reference a private docker image in your workflow files, replace the uri with a {{MyContainer}} placeholder, where "MyContainer" is the name of your repository. For containers you define in the `modules/containers` folder, this will be the folder name. The deployment pipeline will automatically replace the placeholder with the correct ECR URI for your account and region. For example, if you want to use the "biolambda" container, use {{biolambda}}. You can also append an image tag, like {{biolambda:latest}}.
