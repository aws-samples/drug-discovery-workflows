#!/bin/bash

set -ex

REGION=$1
ACCOUNT=$2
TAG=${3:-latest}

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# build esm3
cd esm3
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/esm3:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/esm3:$TAG
cd ..
