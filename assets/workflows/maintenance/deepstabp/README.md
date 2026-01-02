# deepSTABp

This repository helps you set up and run deepSTABp on AWS HealthOmics.

The following setup steps below assume you are starting from scratch and prefer to use the command line. This repository will also have 1-click build capabilities at the root of the repo.

## Running a workflow

Pick your CSV file to run your fist end-to-end test. The following command can be done from the terminal or you can navigate to the AWS console. Note that deepSTABp likely will work best using `STATIC` run storage due to low data volumes and faster startup times.

### Example params.json

```json
{
    "input_fasta": "s3://my-bucket/deepstabp/input.fasta"
}
```
### Running the Workflow

Replace `$ROLEARN`, `$OUTPUTLOC`, `$PARAMS`, `$WFID` as appropriate. Also modify the `params.json` to point to where your FASTA resides.

```bash
WFID=1234567
ROLEARN=arn:aws:iam::0123456789012:role/omics-workflow-role-0123456789012-us-east-1
OUTPUTLOC=s3://mybuckets/run_outputs/deepstabp
PARAMS=./params.json

aws omics start-run --workflow-id $WFID --role-arn $ROLEARN --output-uri $OUTPUTLOC --storage-type STATIC --storage-capacity 4800 --parameters file://$PARAMS --name deepstabp
```
All results are written to a location defined within `$OUTPUTLOC` above. To get to the root directory of the ouputs, you can use the `GetRun` API, which provides the path as `runOutputUri`. Alternatively, this location is available in the console.

## Citation

deepSTABp was developed by Felix Jung. The original source code can be found [here](https://git.nfdi4plants.org/f_jung/deepstabp). The algorithm is presented in the following papers.

https://www.mdpi.com/1422-0067/24/8/7444

```
@Article{ijms24087444,
AUTHOR = {Jung, Felix and Frey, Kevin and Zimmer, David and Mühlhaus, Timo},
TITLE = {DeepSTABp: A Deep Learning Approach for the Prediction of Thermal Protein Stability},
JOURNAL = {International Journal of Molecular Sciences},
VOLUME = {24},
YEAR = {2023},
NUMBER = {8},
ARTICLE-NUMBER = {7444},
URL = {https://www.mdpi.com/1422-0067/24/8/7444},
PubMedID = {37108605},
ISSN = {1422-0067},
ABSTRACT = {Proteins are essential macromolecules that carry out a plethora of biological functions. The thermal stability of proteins is an important property that affects their function and determines their suitability for various applications. However, current experimental approaches, primarily thermal proteome profiling, are expensive, labor-intensive, and have limited proteome and species coverage. To close the gap between available experimental data and sequence information, a novel protein thermal stability predictor called DeepSTABp has been developed. DeepSTABp uses a transformer-based protein language model for sequence embedding and state-of-the-art feature extraction in combination with other deep learning techniques for end-to-end protein melting temperature prediction. DeepSTABp can predict the thermal stability of a wide range of proteins, making it a powerful and efficient tool for large-scale prediction. The model captures the structural and biological properties that impact protein stability, and it allows for the identification of the structural features that contribute to protein stability. DeepSTABp is available to the public via a user-friendly web interface, making it accessible to researchers in various fields.},
DOI = {10.3390/ijms24087444}
}
```
