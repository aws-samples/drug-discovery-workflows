# Predict Protein Complex Structures

## Summary

Predict the structure of biomolecular complexes, including proteins, DNA, RNA, and small molecules.

## Workflow

```mermaid

flowchart TD
    A[FASTA file] --> B(Colabfold-Search)
    B --> B1((.a3m files))
    B --> B2((.m8 file))
    B1 --> C(Chai-1)
    D[Constraints file] --> C
    B2 --> C
    A --> C
    C --> C1((Structure Predictions))

```

## Example

Replace <WORKFLOW_ID>, <IAM_ROLE>, <RUN_NAME>, and <DEPLOYMENT_BUCKET_NAME> with the correct values for your deployment.

```bash
aws omics start-run \
  --cli-input-json \
  '{
    "workflowId": <WORKFLOW_ID>,
    "workflowType": "PRIVATE",
    "roleArn": <IAM_ROLE>,
    "name": <RUN_NAME>,
    "parameters": {
      "query": "s3://<DEPLOYMENT_BUCKET_NAME>/ref-data/chai/8cyo.fasta",
      "constraints_path": "s3://<DEPLOYMENT_BUCKET_NAME>/ref-data/chai/8cyo.restraints",
      "use_msa": 1,
      "use_templates": 1
    },
    "storageType": "DYNAMIC",
    "outputUri": "s3://<DEPLOYMENT_BUCKET_NAME>/tests/outputs/"
}'
```
