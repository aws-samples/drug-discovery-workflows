#!/bin/bash

set -ex

REGION=$1
ACCOUNT=$2
TAG=${3:-latest}

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# build rfantibody
cd rfantibody
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/rfantibody:$TAG .
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/rfantibody:$TAG
cd ..

