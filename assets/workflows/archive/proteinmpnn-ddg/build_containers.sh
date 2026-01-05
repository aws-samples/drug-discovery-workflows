#!/bin/bash

set -ex

REGION=$1
ACCOUNT=$2
TAG=${3:-latest}

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# build proteinmpnn-ddg
cd proteinmpnn-ddg
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/proteinmpnn-ddg:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/proteinmpnn-ddg:$TAG
cd ..

