# Getting Started

This repository helps you set up and run AlphaFold Multimer on AWS HealthOmics. At the end of the configuration, you should be able to run a full end-to-end inference.

AlphaFold-Multimer requires several steps: at a high level they bundle into:
1. Download and prepare the data
2. Multisequence alignment (MSA) 
3. Inference

Traditionally, the download and prepare data stage will download `tar.gz` files and unpack. This script has a series of optimizations that are designed to improve data staging times. On average, we have seen improvements of ~75min on data staging. These are: 
1. Declare specific files to download rather than just rely on recursive download. This takes advantage of AWS HealthOmics' ability to scale out downloads horizontally. You can find these locations in the `nextflow.config` file.
2. Keep the unpacked data in S3 and download there. This removes the need for `tar.gz` files. The compute resources associated with data preparation cost more and increase data preparation times. Instead, you're offloading the compute resources to HealthOmics imports, which is free for customers. Second, storage costs go down in HealthOmics as the overall run time decreases. While this increases S3 footprint, this is modest compared to the overall run savings.

Additionally, the inference step includes a unified memory declaration, which is needed for larger residue sizes. This effectively spills over memory utilization for GPU-mem to vRAM in the cases where it is needed. There may be additional optimizations that can be made here.

## Containers

### Step 1: Create ECR Repositories

There are three containers used: `protein-utils`, `alphafold-data`, `alphafold-predict` in ECR. Feel free to use your preferred method of choice to create the ECR respositories and set the appropriate policies. The below is an example using AWS-owned keys for encryption.

```
cd containers
for repo in protein-utils alphafold-data alphafold-predict
do

aws ecr create-repository --repository-name $repo --encryption-configuration encryptionType=AES256
sleep 5
aws ecr set-repository-policy --repository-name $repo --policy-text file://omics-container-policy.json
sleep 1

done
```

### Step 2: Build containers

Add your AWS account and region to the below. The rest is encapsulated in `build_containers.sh`. This assumes you've completed **Step 1** and are still in the `containers` directory.

```
REGION=<fill_in>
ACCOUNT=<fill_in>
chmod +x build_containers.sh
./build_containers.sh $REGION $ACCOUNT
```

## Workflows

### Step 3: Update Nextflow config with repository locations

Now that your Docker images are created, let's create the workflow. In HealthOmics, this is as simple as creating a zip file and uploading the workflow. Before we do that, though, let's modify the `nextflow.config` to make sure the right instances are referenced. Update your repositories appropriately.

Assuming you still have your region/account environment variables, you can do the following in the root directory of the repository:

```
sed -i 's/123456789012/'$ACCOUNT'/' nextflow.config
sed -i 's/123456789012/'$REGION'/' nextflow.config
```

### Step 4: Create Workflow

You can now zip and create your workflow. Feel free to also use your favorite infrastructure as code tool, but also you can do the following from the command line. Ensure you're in the root directory of the repository.

```
ENGINE=NEXTFLOW
zip -r ../alphafold-multimer.zip .

aws omics create-workflow --engine $ENGINE --definition-zip fileb://../alphafold-multimer.zip --main main.nf --name alphafold-multimer --parameter-template file://parameter-template.json
```

Note the workflow ID you get in the response

### Step 5: Run a workflow
Pick your favorite small fasta file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console.

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WORKFLOWID` as appropriate. Also modify the `run_params.json` to point to where your FASTA resides.

```
ENGINE=NEXTFLOW
ROLEARN=arn:aws:iam::$ACCOUNT:role/omics-workflow-role-$ACCOUNT-REGION
OUTPUTLOC=s3://<your-output-location>
PARAMS=run_params.json
WORKFLOWID=1234567 # replace with the ID in step 4

aws omics start-run --workflow-id $WORKFLOWID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name test-af-multimer
```
