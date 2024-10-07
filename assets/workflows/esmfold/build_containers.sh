#!/bin/bash

set -ex

REGION=$1
ACCOUNT=$2
TAG=${3:-latest}

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# build biolambda
cd biolambda
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/biolambda:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/biolambda:$TAG
cd ..

# build esm2
cd esm2
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/esm2:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/esm2:$TAG
cd ..

# TODO: esmfold?
