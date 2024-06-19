#!/bin/bash

REGION=$1
ACCOUNT=$2

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# build protein-utils
cd protein-utils 
docker build -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/protein-utils:latest .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/protein-utils:latest
cd ..

# build alphafold-data
cd alphafold-data
docker build -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-data:latest .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-data:latest
cd ..

# build alphafold-predict
cd alphafold2
docker build -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-predict:latest .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-predict:latest
cd ..