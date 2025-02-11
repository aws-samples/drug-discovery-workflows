#!/bin/bash

# Adapted from from https://github.com/sokrypton/ColabFold/blob/main/setup_databases.sh
# Setup everything for using mmseqs locally
# Run using GPU=1 ./setup_databases.sh /path/to/db_folder
set -ex

WORKDIR="${1:-$(pwd)}"

UNIREF30DB="uniref30_2302"
MMSEQS_NO_INDEX=${MMSEQS_NO_INDEX:-}
GPU=${GPU:-}
mkdir -p -- "${WORKDIR}"
cd "${WORKDIR}"

# Make MMseqs2 merge the databases to avoid spamming the folder with files
export MMSEQS_FORCE_MERGE=1

GPU_PAR=""
GPU_INDEX_PAR=""
if [ -n "${GPU}" ]; then
  GPU_PAR="--gpu 1"
  GPU_INDEX_PAR=" --split 1 --index-subset 2"

  if ! mmseqs --help | grep -q 'gpuserver'; then
    echo "The installed MMseqs2 has no GPU support, update to at least release 16"
    exit 1
  fi
fi

if [ ! -f UNIREF30_READY ]; then
  mmseqs tsv2exprofiledb "${UNIREF30DB}" "${UNIREF30DB}_db" ${GPU_PAR}
  if [ -z "$MMSEQS_NO_INDEX" ]; then
    mmseqs createindex "${UNIREF30DB}_db" tmp1 --remove-tmp-files 1 ${GPU_INDEX_PAR}
  fi
  if [ -e ${UNIREF30DB}_db_mapping ]; then
    ln -sf ${UNIREF30DB}_db_mapping ${UNIREF30DB}_db.idx_mapping
  fi
  if [ -e ${UNIREF30DB}_db_taxonomy ]; then
    ln -sf ${UNIREF30DB}_db_taxonomy ${UNIREF30DB}_db.idx_taxonomy
  fi
  touch UNIREF30_READY
fi

if [ ! -f COLABDB_READY ]; then
  mmseqs tsv2exprofiledb "colabfold_envdb_202108" "colabfold_envdb_202108_db" ${GPU_PAR}
  # TODO: split memory value for createindex?
  if [ -z "$MMSEQS_NO_INDEX" ]; then
    mmseqs createindex "colabfold_envdb_202108_db" tmp2 --remove-tmp-files 1 ${GPU_INDEX_PAR}
  fi
  touch COLABDB_READY
fi
