

# Build Docker image and push to ECR
```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 588738610715.dkr.ecr.us-east-1.amazonaws.com
docker build -t biophi .
docker tag biophi:latest 588738610715.dkr.ecr.us-east-1.amazonaws.com/biophi:latest
docker push 588738610715.dkr.ecr.us-east-1.amazonaws.com/biophi:latest
```

# Local testing using the Docker container
```
## Download OASis database
## Download database file
wget https://zenodo.org/record/5164685/files/OASis_9mers_v1.db.gz
## Unzip
gunzip OASis_9mers_v1.db.gz

## make example input file
printf ">Muromonab-CD3_VL\nQIVLTQSPAIMSASPGEKVTMTCSASSSVSYMNWYQQKSGTSPKRWIYDTSKLASGVPAHFRGSGSGTSYSLTISGMEAEDAATYYCQQWSSNPFTFGSGTKLEIN\n>Muromonab-CD3_VH\nQVQLQQSGAELARPGASVKMSCKASGYTFTRYTMHWVKQRPGQGLEWIGYINPSRGYTNYNQKFKDKATLTTDKSSSTAYMQLSSLTSEDSAVYYCARYYDDHYCLDYWGQGTTLTVSS" > testab.fa

## Run docker container and access the command line inside the container, 
## using host GPUs and mounting local directory to /tmp/ inside the container
docker run --gpus all -v ./:/tmp/ -it --entrypoint="/bin/bash" biophi

## Get mean Sapiens score (one score for each sequence)
biophi sapiens /tmp/testab.fa --mean-score-only --output /tmp/scores.csv

# Get OASis humanness evaluation
biophi oasis /tmp/testab.fa \
     --oasis-db /tmp/OASis_9mers_v1.db \
     --output /tmp/oasis.xlsx
```

# Creating an AHO private workflow
```
cd aho_workflow
zip definition.zip main.nf nextflow.config parameter-template.json
aws omics create-workflow --engine NEXTFLOW \
  --definition-zip fileb://./definition.zip \
  --name biophi \
  --parameter-template file://./parameter-template.json \
  --region us-east-1 \
  --description "BioPhi for antibody humanization and humanness evaluation."
rm definition.zip
```

# Running the AHO workflow
To create a RUN with the name "ML-guided-DE_test" from the workflow we created above, 
with the input params specified in `aho_workflow/params.json`, run:
```
cd aho_workflow
export ROLEARN=arn:aws:iam::588738610715:role/OmicsRunWorkflow
export OUTPUTLOC=s3://hodgkin-spt-data-us-east-1/test_data/biophi/wf_output
export WORKFLOWID=
aws omics start-run --workflow-id $WORKFLOWID \
  --role-arn $ROLEARN \
  --output-uri $OUTPUTLOC \
  --storage-type STATIC \
  --parameters file://./params.json \
  --name biphi_test \
  --region us-east-1
```