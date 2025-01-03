# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
