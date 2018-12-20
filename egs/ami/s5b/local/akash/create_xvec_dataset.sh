#!/bin/bash

. ./cmd.sh
. ./path.sh

# You may set 'mic' to:
#  ihm [individual headset mic- the default which gives best results]
#  sdm1 [single distant microphone- the current script allows you only to select
#        the 1st of 8 microphones]
#  mdm8 [multiple distant microphones-- currently we only support averaging over
#       the 8 source microphones].
# ... by calling this script as, for example,
# ./run.sh --mic sdm1
# ./run.sh --mic mdm8
mic=ihm

# Train systems,
nj=12 # number of parallel jobs,
nj_gpu=3 # used to decide total jobs for training. change if running out of GPU memory 
stage=1
XVEC_ROOT=/data/akashmjn/kaldi/egs/voxceleb/v2-lial
nnet_dir=$XVEC_ROOT/exp/xvector_nnet_1a.old
dset_suffix="xvecinp"

. utils/parse_options.sh

base_mic=$(echo $mic | sed 's/[0-9]//g') # sdm, ihm or mdm
nmics=$(echo $mic | sed 's/[a-z]//g') # e.g. 8 for mdm8.
min_seg_len=1.55 # see run_ivector_common.sh in local/nnet3

set -euo pipefail

if [ $stage -le 1 ]; then
  printf "\n================ Stage 1 =================\n\n"
  # Make MFCCs and compute the energy-based VAD for each dataset
  for dset in train_sp dev eval; do
    
    if [ ! -e data/${mic}/${dset}_${dset_suffix}/cmvn.scp ]; then
    # start a new dir for xvec input data
    utils/copy_data_dir.sh data/$mic/${dset} data/$mic/${dset}_${dset_suffix}

    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc_xvec.conf \
        --nj $nj --cmd "$train_cmd" data/$mic/${dset}_${dset_suffix}
    steps/compute_cmvn_stats.sh data/$mic/${dset}_${dset_suffix}
    utils/fix_data_dir.sh data/$mic/${dset}_${dset_suffix} # ensure things are cleaned up
    fi

    # only for train, combine short segments to form train_sp_comb_xvecinp
    # combining short segments for better training of chain models   
    if [ $dset == "train_sp" ]; then
      if [ ! -e data/${mic}/${dset}_${dset_suffix}_comb/cmvn.scp ]; then
      utils/data/combine_short_segments.sh \
          data/${mic}/${dset}_${dset_suffix} $min_seg_len \
          data/${mic}/${dset}_comb_${dset_suffix}
      # just copy over the CMVN to avoid having to recompute it.
      cp data/${mic}/${dset}_${dset_suffix}/cmvn.scp \
          data/${mic}/${dset}_comb_${dset_suffix}
      utils/fix_data_dir.sh data/${mic}/${dset}_comb_${dset_suffix} # ensure cleaned up
      fi
      dset="train_sp_comb"
    fi

    if [ ! -e data/${mic}/${dset}_${dset_suffix}/vad.scp ]; then
    steps/compute_vad_decision.sh --vad-config conf/vad_xvec.conf \
        --nj $nj --cmd "$train_cmd" data/$mic/${dset}_${dset_suffix}
    utils/fix_data_dir.sh data/${mic}/${dset}_${dset_suffix} # ensure cleaned up
    fi

  done
fi

# x-vector extraction/computation

if [ $stage -le 2 ]; then
  printf "\n================ Stage 2 =================\n\n"

  for dset in train_sp_comb dev eval; do
  # Extract x-vectors for centering, LDA, and PLDA training.
  $XVEC_ROOT/sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd" --nj $nj \
    $nnet_dir data/${mic}/${dset}_${dset_suffix} \
    data/${mic}/${dset}_xvec    
  done

fi

printf "\n================ Stage 2 completed =================\n\n"
exit

if [ $stage -le 11 ]; then
  $train_cmd exp/scores/log/voxceleb1_test_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    "ivector-copy-plda --smoothing=0.0 $nnet_dir/xvectors_train/plda - |" \
    "ark:ivector-subtract-global-mean $nnet_dir/xvectors_train/mean.vec scp:$nnet_dir/xvectors_voxceleb1_test/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean $nnet_dir/xvectors_train/mean.vec scp:$nnet_dir/xvectors_voxceleb1_test/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$voxceleb1_trials' | cut -d\  --fields=1,2 |" exp/scores_voxceleb1_test || exit 1;
fi


if [ $stage -le 12 ]; then
  local/prepare_for_eer.py $voxceleb1_trials exp/scores_voxceleb1_test >eer.txt 2>&1 &
  
  compute-eer eer.txt 
  mindcf1=`sid/compute_min_dcf.py --p-target 0.01 exp/scores_voxceleb1_test $voxceleb1_trials 2> /dev/null`
  mindcf2=`sid/compute_min_dcf.py --p-target 0.001 exp/scores_voxceleb1_test $voxceleb1_trials 2> /dev/null`
  echo "EER: $eer%"
  echo "minDCF(p-target=0.01): $mindcf1"
  echo "minDCF(p-target=0.001): $mindcf2"
  # EER: 3.128%
  # minDCF(p-target=0.01): 0.3258
  # minDCF(p-target=0.001): 0.5003
  #
  # For reference, here's the ivector system from ../v1:
  # EER: 5.329%
  # minDCF(p-target=0.01): 0.4933
  # minDCF(p-target=0.001): 0.6168
fi
