#!/bin/bash

. ./cmd.sh 
. ./path.sh 

for dset in $@ 
do
  printf "\n ======= Generating forced alignments for /data/ihm/$dset with tri3 model ====== \n\n"
  steps/align_fmllr.sh --nj 12 --cmd run.pl data/ihm/$dset data/lang exp/ihm/tri3 exp/ihm/tri3_ali_$dset
done

