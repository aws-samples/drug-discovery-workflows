# Boltz-MSA Workflow

## Overview

The Boltz-MSA workflow is an AWS HealthOmics private workflow that combines ColabFold MSA (Multiple Sequence Alignment) search with Boltz-2 structure prediction. This end-to-end pipeline automatically generates high-quality MSA files for protein sequences and uses them to improve the accuracy of Boltz-2 structure predictions.

### Key Features

- **Automatic MSA Generation**: Extracts protein sequences from Boltz YAML input and generates MSAs using ColabFold search (MMseqs2)
- **Seamless Integration**: Automatically updates input YAML with MSA file paths for Boltz-2 consumption
- **High-Quality Predictions**: Leverages MSA data to improve structure prediction accuracy
- **Flexible Input**: Supports proteins, RNA/DNA, ligands, constraints, and templates
- **GPU-Accelerated**: Optimized for AWS HealthOmics GPU instances

### Workflow Stages

```
Input YAML → Extract Proteins → ColabFold MSA Search → Update YAML → Boltz-2 Prediction
```

1. **ExtractProteins**: Parses input YAML and extracts unique protein sequences into FASTA format
2. **ColabfoldSearchTask**: Runs MMseqs2 search against UniRef30, EnvDB, and PDB100 databases
3. **UpdateYamlWithMsa**: Modifies input YAML to include MSA file paths for each protein
4. **Boltz2Task**: Runs Boltz-2 structure prediction using the updated YAML with MSAs

## Prerequisites

### Required AWS Resources

- AWS HealthOmics workflow execution role with appropriate permissions
- S3 bucket for workflow outputs
- Reference databases deployed to S3:
  - Boltz-2 model parameters
  - ColabFold UniRef30 database
  - ColabFold EnvDB database
  - ColabFold PDB100 database

### GPU Requirements

- **MSA Search**: 1x nvidia-l40s GPU (64 CPUs, 486 GB memory)
- **Boltz Prediction**: 1x nvidia-tesla-a10g GPU (4 CPUs, 16 GB memory)

## Input Format

### Boltz YAML Input

The workflow accepts Boltz-2 YAML input files following this format:

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE...
  - protein:
      id: B
      sequence: DIFFERENTSEQUENCE...
  - ligand:
      id: C
      ccd: SAH
  - ligand:
      id: D
      smiles: N[C@@H](Cc1ccc(O)cc1)C(=O)O
```

**Supported Entity Types:**

- `protein`: Amino acid sequences
- `rna`: RNA nucleotide sequences
- `dna`: DNA nucleotide sequences
- `ligand`: Small molecules (SMILES notation or CCD codes)

**Optional Fields:**

- `msa`: MSA file path (automatically added by this workflow)
- `templates`: Structural templates
- `constraints`: Distance constraints between residues/atoms

### Input File Location

The input YAML file should be:

- Uploaded to S3 (e.g., `s3://my-bucket/inputs/example.yaml`)
- Specified in the `input_path` parameter when starting the workflow run

## Parameters

### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `input_path` | String | S3 URI or path to Boltz YAML input file | `s3://my-bucket/inputs/example.yaml` |

### Optional Parameters (with Defaults)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `boltz_parameters` | String | `s3://{{S3_BUCKET_NAME}}/ref-data/boltz/boltz-community/boltz-2/` | Path to Boltz model parameters |
| `uniref30_db_path` | String | `s3://{{S3_BUCKET_NAME}}/ref-data/colabfold_uniref30` | Path to UniRef30 database |
| `envdb_db_path` | String | `s3://{{S3_BUCKET_NAME}}/ref-data/colabfold_envdb` | Path to EnvDB database |
| `pdb100_db_path` | String | `s3://{{S3_BUCKET_NAME}}/ref-data/colabfold_pdb100` | Path to PDB100 database |
| `is_complex` | Integer | `1` | Generate paired MSAs for complexes (1) or single chains (0) |

**Note**: The `{{S3_BUCKET_NAME}}` placeholder is automatically replaced during deployment with your actual S3 bucket name.

## Usage

### Example params.json

Create a `params.json` file with your workflow parameters:

```json
{
  "input_path": "s3://my-bucket/inputs/protein_complex.yaml",
  "boltz_parameters": "s3://my-bucket/ref-data/boltz/boltz-community/boltz-2/",
  "uniref30_db_path": "s3://my-bucket/ref-data/colabfold_uniref30",
  "envdb_db_path": "s3://my-bucket/ref-data/colabfold_envdb",
  "pdb100_db_path": "s3://my-bucket/ref-data/colabfold_pdb100",
  "is_complex": 1
}
```

### Starting a Workflow Run

Using AWS CLI:

```bash
aws omics start-run \
  --workflow-id <WORKFLOW_ID> \
  --role-arn <EXECUTION_ROLE_ARN> \
  --output-uri s3://my-bucket/outputs/ \
  --storage-type DYNAMIC \
  --parameters file://params.json \
  --region us-east-1
```

**Storage Type Recommendation**: Use `DYNAMIC` storage (AWS recommended) for most workflows. It auto-scales storage and throughput based on usage, eliminating the need to estimate storage requirements.

### Monitoring Run Progress

Check run status:

```bash
aws omics get-run --id <RUN_ID> --region us-east-1
```

View task logs in CloudWatch Logs:

- Log group: `/aws/omics/WorkflowLog`
- Log stream: `<RUN_ID>/<TASK_ID>`

## Outputs

The workflow publishes outputs to the specified S3 output URI with the following structure:

```
s3://my-bucket/outputs/<RUN_ID>/
├── input/
│   └── example.yaml                    # Original input YAML
├── intermediate/
│   ├── proteins.fasta                  # Extracted protein sequences
│   ├── protein_map.json                # Chain ID to sequence hash mapping
│   └── has_proteins.txt                # Flag indicating if proteins were found
├── msa/
│   ├── A.a3m                          # MSA for chain A (UniRef30)
│   ├── A.bfd.mgnify30.metaeuk30.smag30.a3m  # MSA for chain A (EnvDB)
│   └── B.a3m                          # MSA for chain B (if different sequence)
├── templates/
│   ├── A.pdb70.m8                     # Template hits for chain A
│   └── B.pdb70.m8                     # Template hits for chain B
├── updated_yaml/
│   └── updated_input.yaml             # YAML with MSA paths added
└── boltz_predictions/
    ├── boltz_results_example/
    │   ├── predictions/
    │   │   ├── sample0/
    │   │   │   ├── model.cif          # Predicted structure (mmCIF format)
    │   │   │   └── model.pdb          # Predicted structure (PDB format)
    │   │   └── sample0_confidences.json  # Confidence scores
    │   └── data.yaml                  # Processed input data
    └── ...
```

### Output Files Description

**Input Files:**

- `example.yaml`: Original input YAML for reference

**Intermediate Files:**

- `proteins.fasta`: FASTA file with unique protein sequences extracted from input
- `protein_map.json`: JSON mapping chain IDs to sequence hashes (for deduplication)
- `has_proteins.txt`: Boolean flag indicating whether proteins were found

**MSA Files:**

- `*.a3m`: Multiple sequence alignment files in A3M format
- Two MSA files per unique protein sequence:
  - `<chain>.a3m`: UniRef30 MSA
  - `<chain>.bfd.mgnify30.metaeuk30.smag30.a3m`: Combined EnvDB MSA

**Template Files:**

- `*.m8`: Template hit files in M8 format (BLAST tabular output)

**Updated YAML:**

- `updated_input.yaml`: Modified input YAML with MSA paths added to protein entries

**Boltz Predictions:**

- `model.cif` / `model.pdb`: Predicted 3D structures
- `*_confidences.json`: Confidence scores (pLDDT, PTM, iPTM, PDE, PAE)
- `*_affinity.json`: Binding affinity predictions (if applicable)

### Confidence Scores

The `*_confidences.json` file contains:

```json
{
  "plddt": [85.2, 87.1, ...],           // Per-residue confidence (0-100)
  "ptm": 0.89,                           // Predicted TM-score (0-1)
  "iptm": 0.82,                          // Interface PTM (0-1)
  "pde": [[0.5, 1.2, ...], ...],        // Predicted distance error (Å)
  "pae": [[0.3, 0.8, ...], ...]         // Predicted aligned error (Å)
}
```

**Interpretation:**

- **pLDDT**: Higher is better (>70 = confident, >90 = very confident)
- **PTM/iPTM**: Higher is better (>0.5 = likely correct fold)
- **PDE/PAE**: Lower is better (distances in Angstroms)

## Workflow Behavior

### Protein-Only Inputs

If the input YAML contains only proteins (no ligands, RNA, DNA):

1. Proteins are extracted and MSAs are generated
2. Input YAML is updated with MSA paths
3. Boltz-2 runs with MSA-enhanced predictions

### Mixed Inputs (Proteins + Ligands/RNA/DNA)

If the input YAML contains proteins along with other molecule types:

1. Only protein sequences are extracted for MSA generation
2. MSAs are generated for proteins only
3. Input YAML is updated with MSA paths for proteins
4. Boltz-2 runs with the complete input (proteins with MSAs + other molecules)

### No Proteins

If the input YAML contains no protein sequences (e.g., only ligands or RNA):

1. MSA generation is skipped
2. Original YAML is passed directly to Boltz-2
3. Boltz-2 runs without MSA data

### Sequence Deduplication

If multiple protein chains have identical sequences:

1. MSA is generated only once for the unique sequence
2. All chains with that sequence reference the same MSA file
3. Reduces computation time and storage

## Resource Requirements and Runtime

### Typical Runtime Estimates

| Workflow Stage | Duration | Resources |
|----------------|----------|-----------|
| Extract Proteins | 1-5 minutes | 2 CPUs, 4 GB memory |
| ColabFold MSA Search | 30 minutes - 4 hours | 64 CPUs, 486 GB memory, 1x L40s GPU |
| Update YAML | 1-5 minutes | 2 CPUs, 4 GB memory |
| Boltz-2 Prediction | 20 minutes - 2 hours | 4 CPUs, 16 GB memory, 1x A10G GPU |

**Total Runtime**: 1-6 hours (depending on sequence length and number of chains)

### Cost Optimization

- **Dynamic Storage**: Recommended for most use cases (auto-scales, no capacity planning)
- **GPU Selection**: Workflow uses cost-effective GPU instances (L40s for MSA, A10G for prediction)
- **Retry Strategy**: Tasks automatically retry up to 2 times on transient failures
- **Timeouts**: Tasks have appropriate timeouts to prevent runaway costs

## Troubleshooting

### Common Issues

**Issue**: Workflow fails at ExtractProteins stage

- **Cause**: Invalid or malformed YAML input
- **Solution**: Validate YAML syntax and ensure it follows Boltz-2 format

**Issue**: ColabFold search times out

- **Cause**: Very long sequences or large number of sequences
- **Solution**: Increase timeout in workflow configuration or split into smaller jobs

**Issue**: Boltz prediction fails with GPU memory error

- **Cause**: Complex structure exceeds GPU memory
- **Solution**: Reduce number of diffusion samples or use larger GPU instance

**Issue**: No MSA files generated

- **Cause**: Input YAML contains no protein sequences
- **Solution**: This is expected behavior; workflow will proceed with original YAML

### Viewing Logs

Task logs are available in CloudWatch Logs:

```bash
# Get run details
aws omics get-run --id <RUN_ID> --region us-east-1

# View logs for specific task
aws logs tail /aws/omics/WorkflowLog --follow \
  --log-stream-names <RUN_ID>/<TASK_ID> \
  --region us-east-1
```

### Error Recovery

The workflow includes automatic retry logic:

- Each task retries up to 2 times on failure
- Transient GPU allocation failures are handled automatically
- Permanent failures (e.g., invalid input) fail immediately

## Best Practices

### Input Preparation

1. **Validate YAML**: Ensure input YAML follows Boltz-2 format specification
2. **Sequence Quality**: Use high-quality, validated protein sequences
3. **File Location**: Upload input files to S3 in the same region as HealthOmics
4. **Naming**: Use descriptive names for input files to track results

### Performance Optimization

1. **Batch Processing**: Process multiple predictions in parallel using separate runs
2. **Sequence Deduplication**: Workflow automatically deduplicates identical sequences
3. **Complex Flag**: Set `is_complex=1` for multi-chain complexes to generate paired MSAs
4. **Storage Type**: Use DYNAMIC storage for flexibility and ease of use

### Cost Management

1. **Monitor Runs**: Track run duration and resource usage in HealthOmics console
2. **Right-Size Resources**: Workflow uses optimized resource allocations
3. **Clean Up**: Delete old output files from S3 when no longer needed
4. **Spot Instances**: Consider using spot instances for non-urgent workloads (if supported)

## References

- [Boltz-2 Documentation](https://github.com/jwohlwend/boltz)
- [ColabFold Documentation](https://github.com/sokrypton/ColabFold)
- [AWS HealthOmics Documentation](https://docs.aws.amazon.com/omics/)
- [Nextflow Documentation](https://www.nextflow.io/docs/latest/)

## Support

For issues related to:

- **Workflow execution**: Check CloudWatch logs and HealthOmics console
- **Boltz-2 predictions**: Refer to Boltz-2 documentation and GitHub issues
- **AWS HealthOmics**: Contact AWS Support or refer to AWS documentation

## License

This workflow implementation is provided as-is. Please refer to the licenses of individual tools:

- Boltz-2: MIT License
- ColabFold: MIT License
- MMseqs2: GPLv3 License
