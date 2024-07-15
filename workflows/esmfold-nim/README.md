# ESMFold BioNeMo NIM

This repository helps you set up and run ESMFold using BioNeMo NIM on AWS HealthOmics.

Running BioNeMo NIMs traditionally has several steps.
1. Deploy GPU and configure NVIDIA Triton Inference Server
2. Extract the sequence information from a FASTA file
3. Hit the NIM API with a sequence and get a JSON response.
4. Extract the PDB(s) or other data encoded in the JSON response and save as a separate output.

This HealthOmics workflow automates all of these pieces. Additionally, it contains a couple ergonomic aspects that simplify the process further.
1. Auto-filters input sequences based on a max length. As of 7/15/2024, ESMFold NIM can only accept sequences less than 1024 residues. This is filtered upfront to avoid any failures in chain size.
2. Saves output PDBs based on the FASTA ID.
3. Manages the batch submission process across a NIM in order to maximize the utilization.

## Getting Started

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

### Step 1: Set up ECR
There is one container used: `bionemo_esmfold_nim` in ECR. Feel free to use your preferred method of choice to create the ECR respositories and set the appropriate policies. The below is an example using AWS-owned keys for encryption.

```
cd containers
for repo in bionemo_esmfold_nim
do
aws ecr create-repository --repository-name $repo --encryption-configuration encryptionType=AES256
sleep 5
aws ecr set-repository-policy --repository-name $repo --policy-text file://omics-container-policy.json
sleep 1
done
```

### Step 2: Migrate container from NGC and stage weights

NIMs are currently available via NGC. You must login to NGC, pull the [image](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/nim/containers/bionemo_esmfold_nim) down and then push to Amazon ECR.

Also, be sure to download the model and weights and push to S3. More detailed information can be found on NVIDIA's documentation [here](https://docs.nvidia.com/ai-enterprise/nim-biology/latest/esmfold.html).

Once you have the weights and model paths, update the paths in S3.


### Step 3: Update Nextflow config with repository locations

Now that your Docker images are created, let's create the workflow. In HealthOmics, this is as simple as creating a zip file and uploading the workflow. Before we do that, though, let's modify the `nextflow.config` to make sure the right locations are referenced. Update your repositories appropriately.

### Step 4: Create Workflow

You can now zip and create your workflow. Feel free to also use your favorite infrastructure as code tool, but also you can do the following from the command line. Ensure you're in the root directory of the repository.

 Since this repository contains multiple workflows, you want to set your main entry to `workflows/esmfold-nim/main.nf`. Before deploying, be sure to replace your Docker image locations in your `workflows/esmfold-nim/nextflow.config` as described previously.

```
ENGINE=NEXTFLOW
rm ../drug-discovery-workflows.zip; zip -r ../drug-discovery-workflows.zip .

aws omics create-workflow --engine $ENGINE --definition-zip fileb://../drug-discovery-workflows.zip --main workflows/esmfold-nim/main.nf --name esmfold-nim --parameter-template file://workflows/esmfold-nim/parameter-template.json
```

Note the workflow ID you get in the response.

### Step 5: Run a workflow
Pick your favorite small pdb file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that ESMFold-NIM likely will work best using `DYNAMIC` run storage due to low data volumes and faster startup times.

### Example params.json
Single file:
```
{
    "fasta_path":"s3://mybucket/test_data/monomer/mysequence.fasta"
}
```

Directory:
```
{
    "fasta_path":"s3://mybucket/test_data/monomer/fastas/"
}
```

### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybucket/run_outputs/esmfold-nim
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type DYNAMIC --parameters file://$PARAMS --name esmfold-nim
```

All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation
```
@article{lin2022language,
  title={Language models of protein sequences at the scale of evolution enable accurate structure prediction},
  author={Lin, Zeming and Akin, Halil and Rao, Roshan and Hie, Brian and Zhu, Zhongkai and Lu, Wenting and Smetanin, Nikita and dos Santos Costa, Allan and Fazel-Zarandi, Maryam and Sercu, Tom and Candido, Sal and others},
  journal={bioRxiv},
  year={2022},
  publisher={Cold Spring Harbor Laboratory}
}
```
