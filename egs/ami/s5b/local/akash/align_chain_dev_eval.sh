#!/bin/bash

. ./cmd.sh 
. ./path.sh 

printf "\n ======= Generating dev alignments ====== \n\n"
steps/align_fmllr.sh --nj 12 --cmd run.pl data/ihm/dev data/lang exp/ihm/tri3 exp/ihm/tri3_ali_dev

printf "\n ======= Generating eval alignments ====== \n\n"
steps/align_fmllr.sh --nj 12 --cmd run.pl data/ihm/eval data/lang exp/ihm/tri3 exp/ihm/tri3_ali_eval

