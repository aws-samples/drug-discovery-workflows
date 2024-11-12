# AlphaFold Predict Container

## Desccription

Dockerfile and supporting scripts to run AlphaFold prediction jobs. Does not include dependencies required for data pre-processing, such as MSA generation, structure search, or feature assembly.

## Installation Instructions

```bash

git clone https://github.com/aws-samples/drug-discovery-workflows
cd drug-discovery-workflows/assets/containers/alphafold-predict
docker build . -t alphafold-predict

```
