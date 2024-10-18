# ProteinMPNN

This repository helps you set up and run ProteinMPNN on AWS HealthOmics. Currently, this repository presents a "Hello World" scenario, which can be modified as needed for your specific use case.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

Much of this information (and much more!) can be found at the [ProteinMPNN GitHub repository](https://github.com/dauparas/ProteinMPNN).

## Getting Started

### Step 1: Set up ECR

There is one container used: `proteinmpnn` in ECR. Feel free to use your preferred method of choice to create the ECR respositories and set the appropriate policies. The below is an example using AWS-owned keys for encryption.

```bash
cd containers
for repo in proteinmpnn
do
aws ecr create-repository --repository-name $repo --encryption-configuration encryptionType=AES256
sleep 5
aws ecr set-repository-policy --repository-name $repo --policy-text file://omics-container-policy.json
sleep 1
done
```

### Step 2: Build containers (if not done previously)

Add your AWS account and region to the below. The rest is encapsulated in `build_containers.sh`. This assumes you've completed **Step 1** and are still in the `containers` directory.

```bash
REGION=<fill_in>
ACCOUNT=<fill_in>
cd proteinmpnn

# build
docker build -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/proteinmpnn:latest .

# push
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/proteinmpnn:latest
```

### Step 3: Stage model weights

```bash
BUCKET=mybucket
MODEL_PREFIX=proteinmpnn/model_weights #can change to whatver you prefer

mkdir models && cd models
wget http://files.ipd.uw.edu/pub/RFdiffusion/6f5902ac237024bdd0c176cb93063dc4/Base_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/e29311f6f1bf1af907f9ef9f44b8328b/Complex_base_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/60f09a193fb5e5ccdc4980417708dbab/Complex_Fold_base_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/74f51cfb8b440f50d70878e05361d8f0/InpaintSeq_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/76d00716416567174cdb7ca96e208296/InpaintSeq_Fold_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/5532d2e1f3a4738decd58b19d633b3c3/ActiveSite_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/12fc204edeae5b57713c5ad7dcb97d39/Base_epoch8_ckpt.pt

# Optional:
wget https://raw.githubusercontent.com/dauparas/ProteinMPNN/refs/heads/main/training/exp_020/model_weights/epoch_last.pt

aws s3 cp --recursive ./ s3://${BUCKET}/${MODEL_PREFIX}/
```

### Step 4: Update Nextflow config with repository locations

Now that your Docker images are created, let's create the workflow. In HealthOmics, this is as simple as creating a zip file and uploading the workflow. Before we do that, though, let's modify the `nextflow.config` to make sure the right instances are referenced. Update your repositories appropriately.

Assuming you still have your region/account environment variables, you can do the following in the root directory of the repository:

```bash
sed -i 's/123456789012/'$ACCOUNT'/' workflows/proteinmpnn/nextflow.config
sed -i 's/us-east-1/'$REGION'/' workflows/proteinmpnn/nextflow.config
```

### Step 5: Create Workflow

You can now zip and create your workflow. Feel free to also use your favorite infrastructure as code tool, but also you can do the following from the command line. Ensure you're in the root directory of the repository.

 Since this repository contains multiple workflows, you want to set your main entry to `workflows/proteinmpnn/main.nf`. Before deploying, be sure to replace your Docker image locations in your `workflows/proteinmpnn/nextflow.config` as described previously.

```bash
ENGINE=NEXTFLOW
rm ../drug-discovery-workflows.zip; zip -r ../drug-discovery-workflows.zip .

aws omics create-workflow --engine $ENGINE --definition-zip fileb://../drug-discovery-workflows.zip --main workflows/proteinmpnn/main.nf --name proteinmpnn --parameter-template file://workflows/proteinmpnn/parameter-template.json
```

Note the workflow ID you get in the response.

### Step 6: Run a workflow

Pick your favorite small pdb file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that RFDiffusion likely will work best using `DYNAMIC` run storage due to low data volumes and faster startup times.

### Example params.json

Single file:

```json
{
    "container_image":"123456789012.dkr.ecr.us-east-1.amazonaws.com/proteinmpnn:latest",
    "pdb_path":"s3://mybucket/test_data/proteinmpnn/inputs/PDB_monomers/pdbs/5L33.pdb",
    "model_weights":"s3://mybucket/proteinmpnn/training/exp_020/model_weights/",
    "pdb_path_chains": "A",
    "num_seq_per_target": 8,
    "sampling_temp": "0.1",
    "seed": 37,
    "batch_size": 1
}
```

### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/proteinmpnn
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type DYNAMIC --parameters file://$PARAMS --name rfdiffusion
```

All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation

The original ProteinMPNN paper can be found [here](https://pubmed.ncbi.nlm.nih.gov/36108050/).

@article{dauparas2022robust,
  title={Robust deep learning--based protein sequence design using ProteinMPNN},
  author={Dauparas, Justas and Anishchenko, Ivan and Bennett, Nathaniel and Bai, Hua and Ragotte, Robert J and Milles, Lukas F and Wicky, Basile IM and Courbet, Alexis and de Haas, Rob J and Bethel, Neville and others},
  journal={Science},
  volume={378},
  number={6615},  
  pages={49--56},
  year={2022},
  publisher={American Association for the Advancement of Science}
}