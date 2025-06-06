# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.20.0] - 2025-06-06

### 2.20.0 Changed

- Archive OpenFold workflow

### 2.20.0 Fixed

- Fix bug related to existing ECR repositories without AWS HealthOmics permission policy
- Fix bug related to new traced_sdpa_esm2_t36_3B_UR50D_fp16.pt parameter file for Chai-1 model

---

## [2.19.0] - 2025-03-25

### 2.19.0 Added

- Added support for RFAntibody

### 2.19.0 Changed

- Merge AlphaFold containers
- Extend PPL calcualtions to include ESM2

### 2.19.0 Fixed

- Fix bug related to processing MSA and template search results for Chai-1

---

## [2.18.1] - 2025-03-10

### 2.18.1 Fixed

- Fixed typo in Boltz-1 parameter URI

---

## [2.18.0] - 2025-03-07

### 2.18.0 Added

- Added support for Boltz-1 (Single Sequence Mode)
- Added support for Deepstabp
- Added support for Efficient Evolution
- Added support for Efficient Evolution
- Added support for ProteinMPNN-DDG
- Added support for PEP-Patch
- Added support for AggreScan 3D

---

## [2.17.0] - 2025-03-07

### 2.17.0 Added

- Added support for OpenFold2

---

## [2.16.0] - 2025-03-06

### 2.16.0 Added

- Added support for Colabfold-search workflow to generate MSA files.
- Added protein complex prediction workflow.

### 2.16.0 Changed

- Updated Chai-1 workflow to support MSA, template, and constraint files.
- Updated the indexed Uniref30 data source to S3.

---

## [2.15.1] - 2025-02-19

### 2.15.1 Fixed

- Updated container build logic in scripts/testrun.sh
- Added missing modules to README

---

## [2.15.0] - 2025-02-18

### 2.15.0 Added

- Added support for [DiffAb](https://www.biorxiv.org/content/10.1101/2022.07.10.499510v5.abstract) antigen-specific design model from Helixon ([PR 31](https://github.com/aws-samples/drug-discovery-workflows/pull/31))
- Added support for [Humatch](https://github.com/oxpig/Humatch) mAb humanization model from Oxford Protein Informatics Group ([PR 32](https://github.com/aws-samples/drug-discovery-workflows/pull/32))

### 2.15.0 Fixed

- Update transformers version per CVE-2024-11393.

---

## [2.14.1] - 2025-01-29

### 2.14.1 Fixed

- Added missing region variable to Chai-1 base image.
- Updated container build script to better handle missing remote repository credentials.

---

## [2.14.0] - 2025-01-13

### 2.14.0 Fixed

- Updated Uniref30 database to most recent version (2023-02) to avoid known HHBlits issue described at <https://github.com/google-deepmind/alphafold/issues/810>.

---

## [2.13.0] - 2025-01-08

### 2.13.0 Changed

- Updated EvoProtGrad directed evolution workflow to include fine-tuned regression expert.
- Added additional license information to container scripts.

---

## [2.12.0] - 2025-01-03

### 2.12.0 Added

- Added MMseqs2 workflow

### 2.12.0 Changed

- Updated AlphaFold2-Multimer workflow to support multiple input fasta files

---

## [2.11.0] - 2024-12-18

### 2.11.0 Added

- Added AntiFold workflow

---

## [2.10.1] - 2024-12-17

### 2.10.1 Changed

- Small updates to Nanobody design documentation.

---

## [2.10.0] - 2024-12-13

### 2.10.0 Added

- Added TemStaPro prediction workflow.

---

## [2.9.0] - 2024-12-13

### 2.9.0 Added

- Added EquiFold prediction workflow.
- Added BioPhi prediction workflow.

---

## [2.8.0] - 2024-12-11

### 2.8.0 Added

- Added ThermoMPNN thermostability prediction workflow.

---

## [2.7.0] - 2024-12-10

### 2.7.0 Added

- Added Chai-1 biomolecule structure prediction workflow.

---

## [2.6.0] - 2024-12-04

### 2.6.0 Added

- Added NVIDIA BioNeMo NiM protein design workflow.

---

## [2.5.0] - 2024-11-25

### 2.5.0 Added

- Added additional datasets from NVIDIA NGC.
- Added ABodyBuilder3 antibody structure prediction workflow.
- Added NanobodyBuilder2 nanobody structure prediction workflow.

### 2.5.0 Changed

- Updated parallelization of nanobody design workflow to improve throughput.

---

## [2.4.0] - 2024-11-16

### 2.4.0 Added

- Added EvoProtGrad antibody optimization workflow.

---

## [2.3.3] - 2024-11-08

### 2.3.3 Added

- Added AlphaBind antibody optimization workflow.

### 2.3.3 Fixed

- Fixed issue that caused all CodeBuild data jobs to fail without 3rd party credentials.

---

## [2.3.2] - 2024-11-08

### 2.3.2 Added

- Added predicted structure / scaffold RMSD as output for nanobody design workflow.

---

## [2.3.1] - 2024-11-06

### 2.3.1 Added

- Added support 3rd party data download credentials.

---

## [2.3.0] - 2024-11-06

### 2.3.0 Added

- Added support for zero-shot pseudo-perplexity calculation with the AMPLIFY pLM.

---

## [2.2.1] - 2024-11-05

### 2.2.1 Fixed

- Fixed issue where specifying fewer ProteinMPNN results than the batch size produces no sequences.

---

## [2.2.0] - 2024-10-29

### 2.2.0 Added

- Added ProteinMPNN to RFDiffusion workflow
- Added higher-level nanobody design recipe

---

## [2.1.1] - 2024-10-15

### 2.1.1 Changed

- Updated RFDiffusion dependencies

### 2.1.1 Fixed

- Fixed typo in Cfn options
- Increased data download timeout

---

## [2.1.0] - 2024-10-10

### 2.1.0 Added

- AlphaFold2-Monomer workflow
- AlphaFold2-Multimer workflow
- RFDiffusion workflow

---

## [2.0.0] - 2024-10-04

### 2.0.0 Added

- Major changes to deployment process
- Add data download process
- Convert all workflow scrpts to NextFlow
- Update ESM-2 and ESMFold workflows (more coming soon)

---

## [1.2.0] - 2024-06-25

### 1.2.0 Added

- RFDiffusion container
- ProteinMPNN container

---

## [1.1.0] - 2024-06-25

### 1.1.0 Added

- Protein annotations workflow with ESM3
- AlphaFold2 workflow
- AlphaFold2-Multimer workflow

---

## [1.0.0] - 2024-05-01

### 1.0.0 Added

- ESMFold workflow
- ESM-2 embedding workflow

---
