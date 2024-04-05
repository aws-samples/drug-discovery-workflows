# aho-drug-discovery-workflows

## Description

A collection of Amazon HealthOmics workflows to accelerate drug discovery.

## Deployment

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

The CloudFormation deployment should finish in about 3 minutes. It will take another 15 minutes to build the algorithm containers.

Once the deployment has finished, you can create a private workflow run using the Amazon HealthOmics console, CLI, or SDK.

## Development

To add a new module, clone the repository and take a look at the `modules` folder.

```txt
modules/
├── containers
│   ├── esmfold
│   └── protein-utils
└── workflows
    └── esmfold
```

The `containers` subfolder contains Dockerfiles and supporting files to build docker containers. Similarly, `workflows` contains the HeathOmics workflow files (.wdl and .nf) and supporting files to create private workflows. Each subfolder is an independent build context. In other words, if you create a new `containers/my_docker` folder, the deployment process will use it as the context for a `docker build` command. The deployment process will process all subfolders under `containers` and `workflows` without any further configuration. Just drop in your modules and deploy!

To reference a private docker image in your workflow files, replace the uri with a {{MyContainer}} placeholder, where "MyContainer" is the name of your repository. For containers you define in the `modules/containers` folder, this will be the folder name. The deployment pipeline will automatically replace the placeholder with the correct ECR URI for your account and region.
