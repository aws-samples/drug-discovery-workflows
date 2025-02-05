#!/bin/bash

# Functionality for running mmseqs locally. Takes in a fasta file, outputs final.a3m
# Adapted from https://github.com/sokrypton/ColabFold/blob/main/colabfold/mmseqs/search.py
# Original Copyright (c) 2021 Sergey Ovchinnikov
# Modifications Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT License

set -euxo pipefail

QUERY="$1"     # FASTA input
BASE="$2"      # db folder
UNIREF_DB="$3" # uniref30_2302
ENV_DB="$4"    # colabfold_envdb_202108
GPU="$5"       # 0 or 1

USE_ENV=1
FILTER=1
EXPAND_EVAL=inf
ALIGN_EVAL=10
DIFF=3000
QSC=-20.0
MAX_ACCEPT=1000000
if [ "${FILTER}" = "1" ]; then
  ALIGN_EVAL=10
  QSC=0.8
  MAX_ACCEPT=100000
fi
export MMSEQS_CALL_DEPTH=1
SEARCH_PARAM="--num-iterations 3 --db-load-mode 2 -a --k-score 'seq:96,prof:80' -e 0.1 --max-seqs 10000"
FILTER_PARAM="--filter-min-enable 1000 --diff ${DIFF} --qid 0.0,0.2,0.4,0.6,0.8,1.0 --qsc 0 --max-seq-id 0.95"
EXPAND_PARAM="--expansion-mode 0 -e ${EXPAND_EVAL} --expand-filter-clusters ${FILTER} --max-seq-id 0.95"

if [ "${GPU}" = "1" ]; then
  SEARCH_PARAM="${SEARCH_PARAM} --gpu 1 --prefilter-mode 1"
fi

mkdir -p "${BASE}"
mmseqs createdb "${QUERY}" "${BASE}/qdb" --dbtype 1
mmseqs search "${BASE}/qdb" "${UNIREF_DB}" "${BASE}/res" "${BASE}/tmp1" $SEARCH_PARAM
mmseqs mvdb "${BASE}/tmp1/latest/profile_1" "${BASE}/prof_res"
mmseqs lndb "${BASE}/qdb_h" "${BASE}/prof_res_h"

(
  mmseqs expandaln "${BASE}/qdb" "${UNIREF_DB}.idx" "${BASE}/res" "${UNIREF_DB}.idx" "${BASE}/res_exp" --db-load-mode 2 ${EXPAND_PARAM}
  mmseqs align "${BASE}/prof_res" "${UNIREF_DB}.idx" "${BASE}/res_exp" "${BASE}/res_exp_realign" --db-load-mode 2 -e ${ALIGN_EVAL} --max-accept ${MAX_ACCEPT} --alt-ali 10 -a
  mmseqs filterresult "${BASE}/qdb" "${UNIREF_DB}.idx" "${BASE}/res_exp_realign" "${BASE}/res_exp_realign_filter" --db-load-mode 2 --qid 0 --qsc $QSC --diff 0 --max-seq-id 1.0 --filter-min-enable 100
  mmseqs result2msa "${BASE}/qdb" "${UNIREF_DB}.idx" "${BASE}/res_exp_realign_filter" "${BASE}/uniref.a3m" --msa-format-mode 6 --db-load-mode 2 --filter-msa ${FILTER} ${FILTER_PARAM}
  mmseqs rmdb "${BASE}/res_exp_realign"
  mmseqs rmdb "${BASE}/res_exp"
  mmseqs rmdb "${BASE}/res"
  mmseqs rmdb "${BASE}/res_exp_realign_filter"

) &
(

  if [ "${USE_ENV}" = "1" ]; then
    mmseqs search "${BASE}/prof_res" "${ENV_DB}" "${BASE}/res_env" "${BASE}/tmp2" $SEARCH_PARAM
    mmseqs expandaln "${BASE}/prof_res" "${ENV_DB}.idx" "${BASE}/res_env" "${ENV_DB}.idx" "${BASE}/res_env_exp" -e ${EXPAND_EVAL} --expansion-mode 0 --db-load-mode 2
    mmseqs align "${BASE}/tmp2/latest/profile_1" "${ENV_DB}.idx" "${BASE}/res_env_exp" "${BASE}/res_env_exp_realign" --db-load-mode 2 -e ${ALIGN_EVAL} --max-accept ${MAX_ACCEPT} --alt-ali 10 -a
    mmseqs filterresult "${BASE}/qdb" "${ENV_DB}.idx" "${BASE}/res_env_exp_realign" "${BASE}/res_env_exp_realign_filter" --db-load-mode 2 --qid 0 --qsc $QSC --diff 0 --max-seq-id 1.0 --filter-min-enable 100
    mmseqs result2msa "${BASE}/qdb" "${ENV_DB}.idx" "${BASE}/res_env_exp_realign_filter" "${BASE}/bfd.mgnify30.metaeuk30.smag30.a3m" --msa-format-mode 6 --db-load-mode 2 --filter-msa ${FILTER} ${FILTER_PARAM}
    mmseqs rmdb "${BASE}/res_env_exp_realign_filter"
    mmseqs rmdb "${BASE}/res_env_exp_realign"
    mmseqs rmdb "${BASE}/res_env_exp"
    mmseqs rmdb "${BASE}/res_env"
  fi

) &
wait

mmseqs rmdb "${BASE}/qdb"
mmseqs rmdb "${BASE}/qdb_h"
mmseqs rmdb "${BASE}/res"
rm -f -- "${BASE}/prof_res"*
rm -rf -- "${BASE}/tmp1" "${BASE}/tmp2"
