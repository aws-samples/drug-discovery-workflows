#!/bin/bash

set -ex

REGION=$1
ACCOUNT=$2
TAG=${3:-latest}

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# build rfdiffusion
cd rfdiffusion
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/rfdiffusion:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/rfdiffusion:$TAG
cd ..
