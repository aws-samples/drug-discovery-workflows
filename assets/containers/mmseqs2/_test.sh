#!/bin/bash

set -ex

mmseqs gpuserver /home/data/colabfold_envdb_202108_db --max-seqs 10000 --db-load-mode 0 --prefilter-mode 1 &
PID1=$!
echo "colabfold_envdb_202108_db gpuserver running on PID $PID1"
mmseqs gpuserver /home/data/uniref30_2302_db --max-seqs 10000 --db-load-mode 0 --prefilter-mode 1 &
PID2=$!
echo "uniref30_2302_db gpuserver running on PID $PID2"

sleep 10

python colabfold_search.py --gpu 1 --gpu-server 1 \
  $1 \
  /home/data \
  /home/msas

ls /home/msas
