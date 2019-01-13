#!/usr/bin/env bash

# Compiles dev and eval WERs generated after decoding in the provided exp_dir
for d in $@; do for ddecode in $d/decode_*; do echo $ddecode & grep Sum $ddecode/*scor*/*ys | ./utils/best_wer.sh; done; done

