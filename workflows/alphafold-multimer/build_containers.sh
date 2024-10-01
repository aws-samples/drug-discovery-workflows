#!/bin/bash

set -ex

REGION=$1
ACCOUNT=$2
TAG=${3:-latest}

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# build protein-utils
cd protein-utils 
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/protein-utils:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/protein-utils:$TAG
cd ..

# build alphafold-data
cd alphafold-data
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-data:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-data:$TAG
cd ..

# build alphafold-predict
cd alphafold-predict
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-predict:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/alphafold-predict:$TAG
cd ..
