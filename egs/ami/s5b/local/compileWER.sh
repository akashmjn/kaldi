#!/usr/bin/env bash

# Compiles dev and eval WERs generated after decoding in the provided exp_path
exp_path=$1
for d in $exp_path/decode_*; do grep Sum $d/*scor*/*ys | utils/best_wer.sh; done
