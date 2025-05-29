# Protein Sequence Design using AlphaBind

This repository helps you set up and run [AlphaBind](https://github.com/A-Alpha-Bio/alphabind) on AWS HealthOmics for protein sequence design. Currently, this repository presents an example, which can be modified as needed for your specific use case.

AlphaBind is an ESM2 based protein language model to predict protein-protein interaction, e.g. antibody-antigen binding. The binding affinity prediction is just based on protein sequence information, and no structural information is required. The model can be fine tuned with labeled datasets, and it can be used to guide protein sequence design and optimization. 

## Getting Started

### Step 1: Create an S3 bucket in us-east-1

Create an S3 bucket in the us-east-1 region to store your deployment artifacts:

```bash
aws s3 mb s3://your-deployment-bucket-name --region us-east-1
```

### Step 2: Join the NVIDIA Developer Program and Get your NGC API token

1. Join the NVIDIA Developer Program at [https://build.nvidia.com/explore/discover](https://build.nvidia.com/explore/discover)
2. Create a NVIDIA [NGC account](https://docs.nvidia.com/ngc/gpu-cloud/ngc-user-guide/index.html) 
3. [Generate an API key](https://org.ngc.nvidia.com/setup/api-key) to download BioNeMo model weights, e.g. ESM2nv

Create an [AWS Secrets Manager Secret](https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html), if you use [AWS CLI](https://aws.amazon.com/cli/), you can run the following script:

```bash
aws secretsmanager create-secret \
    --name <YourSecretName> \
    --description "My NVIDIA NGC credentials." \
    --secret-string "{\"NGC_CLI_API_KEY\":\"<YourAPIKey>\",\"NGC_CLI_ORG\":\"<YourNGCSignUpOrganization>\"}"
```

### Step 3: Verify your NGC access and store your API token

1. After joining the NVIDIA Developer Program and creating your NGC account, verify your access by:
   - Log in to the NGC website with your credentials
   - Visit [https://catalog.ngc.nvidia.com/orgs/nim/teams/ipd/containers/proteinmpnn/layers](https://catalog.ngc.nvidia.com/orgs/nim/teams/ipd/containers/proteinmpnn/layers)
   - Confirm you can see the container layers. If you cannot see them, your NGC account may not have the proper permissions.

2. Create an [AWS Secrets Manager Secret](https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html), if you use [AWS CLI](https://aws.amazon.com/cli/), you can run the following script:

```bash
aws secretsmanager create-secret \
    --name <YourSecretName> \
    --description "My NVIDIA NGC credentials." \
    --secret-string "{\"NGC_CLI_API_KEY\":\"<YourAPIKey>\",\"NGC_CLI_ORG\":\"<YourNGCSignUpOrganization>\"}" \
    --region us-east-1
```

### Step 4: Deploy the stack to create the container and AWS HealthOmics workflow

You can deploy the stack using the following script. Make sure to deploy to the us-east-1 region:

```bash
bash scripts/deploy.sh \
  -b "<DeploymentS3BucketName>" \
  -n "<CloudFormationStackName>" \
  -r "us-east-1" \
  -s "<YourSecretName>" \
  -w "Y"
```

The `-w "Y"` parameter ensures CloudFormation waits for the CodeBuild process to complete, which helps with troubleshooting.

### Step 5: Run a workflow
Create an IAM role to run HealthOmics jobs, and set up value of `$ROLEARN` to this role ARN. Replace `$OUTPUTLOC` with the S3 folder created for output files like `s3://{mybucket}/alphabind/output/`. Also create a new `params.json` to point to the processed binding affinity data to fine tune AlphaBind model, like:
```txt
{
	"input_training_data": "s3://<yours3bucket>/train_data.csv",
	"max_epochs": 10,
	"seed_sequence": "EVQLVESGGGLVQPGGSLRLSCAASGFNIKDTYIHWVRQAPGKGLEWVARIYPTNGYTRYADSVKGRFTISADTSKNTAYLQMNSLRAEDTAVYYCSRWGGDGFYAMDYWGQGTLVTVSSGGGGSGGGGSGGGGSDIQMTQSPSSLSASVGDRVTITCRASQDVNTAVAWYQQKPGKAPKLLIYSASFLYSGVPSRFSGSRSGTDFTLTISSLQPEDFATYYCQQHYTTPPTFGQGTKVEIKR",
	"mutation_start_idx": 98,
	"mutation_end_idx": 107,
	"target_protein_sequence": "ACHQLCARGHCSGPGPTQCVNCSQFLRGQECVEECRVLQGLPREYVNARHCLPCHPECQPQNGSVTCFGPEADQCVACAHYKDPPFCVARCPSGVKPDLSYMPIWKFPDEEGACQPSPIN",
	"num_seeds": 10,
	"num_generations": 20,
	"generator_type": "esm-simultaneous-random"
}
```

You can follow the data preprocessing step in [this example](https://github.com/A-Alpha-Bio/alphabind/blob/main/alphabind/examples/finetuning_and_inference/tutorial_1_finetuning_alphabind.ipynb) to prepare `train_data.csv` file.

You can run the job using [AWS CLI](https://aws.amazon.com/cli/) from the terminal:
```bash
WFID=
ROLEARN=
OUTPUTLOC=

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --parameters file://./params.json --name alphabindworkflow
```

Or you can navigate to the AWS console to run the job. All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console as well.

## Troubleshooting

If you encounter issues with the CodeBuild process failing during deployment:

1. **Check CloudWatch Logs**: Look for the CodeBuild logs in CloudWatch under the log group `/aws/codebuild/<StackPrefix>-CodeBuildContainerProject`

2. **Verify NGC Credentials**: Ensure your NGC API key is correctly stored in AWS Secrets Manager and that the secret name is properly passed to the deploy script

3. **NGC Access Verification**: If container builds fail with authentication errors, verify you can access the container layers at [https://catalog.ngc.nvidia.com/orgs/nim/teams/ipd/containers/proteinmpnn/layers](https://catalog.ngc.nvidia.com/orgs/nim/teams/ipd/containers/proteinmpnn/layers) while logged in to NGC

4. **Region Compatibility**: Make sure you're deploying to us-east-1 region, as some resources may be region-specific

5. **Container Build Permissions**: Verify that the CodeBuild role has permissions to access ECR and create repositories


