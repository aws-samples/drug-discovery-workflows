# AlphaFold Multimer

This repository helps you set up and run AlphaFold Multimer on AWS HealthOmics. At the end of the configuration, you should be able to run a full end-to-end inference.

AlphaFold-Multimer requires several steps: at a high level they bundle into:
1. Download and prepare the data
2. Multisequence alignment (MSA) 
3. Inference

Traditionally, the download and prepare data stage will download `tar.gz` files and unpack. This workflow has a series of optimizations that are designed to improve data staging times and reduce the time and cost of inference while improving scale (>2500 residues). All corresponding reference data is hosted by AWS HealthOmics, so there is no charge to customers to host that data.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

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
cd alphafold
chmod +x build_containers.sh
./build_containers.sh $REGION $ACCOUNT
```

## Workflows

### Step 3: Update Nextflow config with repository locations

Now that your Docker images are created, let's create the workflow. In HealthOmics, this is as simple as creating a zip file and uploading the workflow. Before we do that, though, let's modify the `nextflow.config` to make sure the right instances are referenced. Update your repositories appropriately.

Assuming you still have your region/account environment variables, you can do the following in the root directory of the repository:

```
sed -i 's/123456789012/'$ACCOUNT'/' workflows/alphafold-multimer/nextflow.config
sed -i 's/us-east-1/'$REGION'/' workflows/alphafold-multimer/nextflow.config
```

### Step 4: Create Workflow

You can now zip and create your workflow. Feel free to also use your favorite infrastructure as code tool, but also you can do the following from the command line. Ensure you're in the root directory of the repository.

 Since this repository contains multiple workflows, you want to set your main entry to `workflows/alphafold-multimer/main.nf`. Before deploying, be sure to replace your Docker image locations in your `workflows/alphafold-multimer/nextflow.config` as described previously.

```
ENGINE=NEXTFLOW
rm ../drug-discovery-workflows.zip; zip -r ../drug-discovery-workflows.zip .

aws omics create-workflow --engine $ENGINE --definition-zip fileb://../drug-discovery-workflows.zip --main workflows/alphafold-multimer/main.nf --name alphafold-multimer --parameter-template file://workflows/alphafold-multimer/parameter-template.json --storage-capacity 4800
```

Note the workflow ID you get in the response

### Step 5: Run a workflow
Pick your favorite small fasta file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console.

### Inputs

`target_id`: The ID of the target you wish to predict
`fasta_path`: S3 URI to a single FASTA file that is in multi-FASTA format. Currently supports 1-chain per record.


### Example params.json
```
{
    "fasta_path":"s3://mybucket/input/multimer/7unl.fasta",
    "target_id": "7unl"
}
```

### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/alphafold
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name alphafold-multimer
```

All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation
AlphaFold Multimer was developed by DeepMind. The original source code can be found [here](https://github.com/google-deepmind/alphafold). The algorithm is presented in the following papers.

```
@Article{AlphaFold2021,
  author  = {Jumper, John and Evans, Richard and Pritzel, Alexander and Green, Tim and Figurnov, Michael and Ronneberger, Olaf and Tunyasuvunakool, Kathryn and Bates, Russ and {\v{Z}}{\'\i}dek, Augustin and Potapenko, Anna and Bridgland, Alex and Meyer, Clemens and Kohl, Simon A A and Ballard, Andrew J and Cowie, Andrew and Romera-Paredes, Bernardino and Nikolov, Stanislav and Jain, Rishub and Adler, Jonas and Back, Trevor and Petersen, Stig and Reiman, David and Clancy, Ellen and Zielinski, Michal and Steinegger, Martin and Pacholska, Michalina and Berghammer, Tamas and Bodenstein, Sebastian and Silver, David and Vinyals, Oriol and Senior, Andrew W and Kavukcuoglu, Koray and Kohli, Pushmeet and Hassabis, Demis},
  journal = {Nature},
  title   = {Highly accurate protein structure prediction with {AlphaFold}},
  year    = {2021},
  volume  = {596},
  number  = {7873},
  pages   = {583--589},
  doi     = {10.1038/s41586-021-03819-2}
}
```

```
@article {AlphaFold-Multimer2021,
  author       = {Evans, Richard and O{\textquoteright}Neill, Michael and Pritzel, Alexander and Antropova, Natasha and Senior, Andrew and Green, Tim and {\v{Z}}{\'\i}dek, Augustin and Bates, Russ and Blackwell, Sam and Yim, Jason and Ronneberger, Olaf and Bodenstein, Sebastian and Zielinski, Michal and Bridgland, Alex and Potapenko, Anna and Cowie, Andrew and Tunyasuvunakool, Kathryn and Jain, Rishub and Clancy, Ellen and Kohli, Pushmeet and Jumper, John and Hassabis, Demis},
  journal      = {bioRxiv},
  title        = {Protein complex prediction with AlphaFold-Multimer},
  year         = {2021},
  elocation-id = {2021.10.04.463034},
  doi          = {10.1101/2021.10.04.463034},
  URL          = {https://www.biorxiv.org/content/early/2021/10/04/2021.10.04.463034},
  eprint       = {https://www.biorxiv.org/content/early/2021/10/04/2021.10.04.463034.full.pdf},
}
```
