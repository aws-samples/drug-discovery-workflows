# Predict Antibody Structure with ABodyBuilder3

## Summary

Predict antibody structures using the [NanoBodyBuilder](https://github.com/oxpig/ImmuneBuilder) model from the Oxford Protein Informatics Group.

## Workflow

```mermaid

flowchart TD
  A[Split FASTA file into chunks of n sequences] --> B[Predict Nanobody structure] --> C[Return structure]
  A --> D[Predict Nanobody structure] --> E[Return structure]

```
