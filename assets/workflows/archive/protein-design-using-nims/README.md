# Protein Design Workflow using NVIDIA BioNeMo NIMs

This protein desing workflow demonstrates how to run [NVIDIA BioNeMo NIMs](https://docs.nvidia.com/nim/#bionemo) on AWS HealthOmics, including [RFdiffusion](https://docs.nvidia.com/nim/bionemo/rfdiffusion/latest/overview.html), [ProteinMPNN](https://docs.nvidia.com/nim/bionemo/proteinmpnn/latest/overview.html), and [AlphaFold2 Multimer](https://docs.nvidia.com/nim/bionemo/alphafold2-multimer/latest/overview.html). Currently, this repository presents a "Hello World" scenario, which can be modified as needed for your specific use case.

The following setup steps below assume you are starting from scratch and prefer to use the [AWS command line interface (CLI)](https://aws.amazon.com/cli/).

## Running a workflow

Download the protein structure in [PDB file (5TPN.pdb)](https://www.rcsb.org/structure/5TPN) and save the [chain A sequence (5TPN_1)](https://www.rcsb.org/fasta/entry/5TPN/display) in FASTA file (e.g. 5TPN_1.fasta) for Human respiratory syncytial virus A2 protein. Upload the pdb file and fasta file to your S3 bucket like `s3://<Your Bucket>/input/pdb/` and `s3:///<Your Bucket>/input/fasta/`, and update the `params.json` with your S3 bucket name:

### Example params.json

Single file:

```json
{
    "pdb_input_path":"s3://<Your Bucket>/input/pdb/",
    "fasta_path":"s3:///<Your Bucket>/input/fasta/",
    "contigs": "A163-181/0 10-40",
    "num_design": 5,
    "input_pdb_chains": "B",
    "num_seq_per_target": 5,
    "max_retries": 2
}
```

### Running the Workflow

The workflow should be created when you run `bash scripts/deploy.sh` script. The workflow name should be `ProteinDesignWorkflow`. You can copy the workflow ID as `$WFID`. Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your PDB and FASTA files reside.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/rfdiffusion
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type DYNAMIC --parameters file://$PARAMS --name proteindesignusingnims
```

All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.


