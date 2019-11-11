#!/bin/bash

set -euo pipefail
set -x

tmpdir=$(mktemp -d)

input=$1
output=$2

mincmath -clamp -const2 0 $(mincstats -max -quiet ${input}) ${input} ${tmpdir}/clamp.mnc

volmash -swap zy ${tmpdir}/clamp.mnc ${tmpdir}/mash.mnc

volcentre -zero_dircos -com ${tmpdir}/mash.mnc ${tmpdir}/centre.mnc

minc_anlm --rician --mt $(nproc) ${tmpdir}/centre.mnc ${tmpdir}/denoise.mnc

minccalc -unsigned -byte -expression '1' ${tmpdir}/denoise.mnc ${tmpdir}/initmask.mnc

ImageMath 3 ${tmpdir}/weight.mnc ThresholdAtMean ${tmpdir}/denoise.mnc 0.5
ImageMath 3 ${tmpdir}/weight.mnc GetLargestComponent ${tmpdir}/weight.mnc

N4BiasFieldCorrection -d 3 -i ${tmpdir}/denoise.mnc -b [30] -c [300x300x300,1e-5] -r 0 -w ${tmpdir}/weight.mnc -x ${tmpdir}/initmask.mnc \
-o ${tmpdir}/N4.mnc -s 4 --verbose

ThresholdImage 3 ${tmpdir}/N4.mnc ${tmpdir}/otsu.mnc Otsu 1

fixedfile=Fisher_rat_atlas/Fischer344_template.mnc
movingfile=${tmpdir}/N4.mnc
fixedmask=Fisher_rat_atlas/Fischer344_mask.mnc
#fixedmask=NOMASK
movingmask=NOMASK

antsRegistration --dimensionality 3 --verbose --minc \
  --output [ ${tmpdir}/reg ] \
  --use-histogram-matching 0 \
  --initial-moving-transform [ ${fixedfile},${movingfile},1 ] \
--transform Translation[ 0.5 ] \
  --metric Mattes[ ${fixedfile},${movingfile},1,32,Regular,0.5 ] \
  --convergence [ 2025x2025x2025,1e-6,10 ] \
  --shrink-factors 8x8x4 \
  --smoothing-sigmas 0.849321800288x0.424660900144x0.212330450072mm \
  --masks [ NOMASK,NOMASK ] \
--transform Rigid[ 0.5 ] \
  --metric Mattes[ ${fixedfile},${movingfile},1,64,Regular,0.5 ] \
  --convergence [ 2025x2025x986,1e-6,10 ] \
  --shrink-factors 8x4x2 \
  --smoothing-sigmas 0.424660900144x0.212330450072x0.106165225036mm \
  --masks [ NOMASK,NOMASK ] \
--transform Similarity[ 0.25 ] \
  --metric Mattes[ ${fixedfile},${movingfile},1,128,Regular,0.75 ] \
  --convergence [ 2025x986x314,1e-6,10 ] \
  --shrink-factors 4x2x1 \
  --smoothing-sigmas 0.212330450072x0.106165225036x0.053082612518mm \
  --masks [ NOMASK,NOMASK ] \
--transform Affine[ 0.1 ] \
  --metric Mattes[ ${fixedfile},${movingfile},1,256,None ] \
  --convergence [ 986x314x177x25,1e-6,10 ] \
  --shrink-factors 2x1x1x1 \
  --smoothing-sigmas 0.106165225036x0.053082612518x0.026541306259x0mm \
  --masks [ ${fixedmask},NOMASK ]

antsApplyTransforms -d 3 -i ${fixedmask} -r ${movingfile} -t [${tmpdir}/reg0_GenericAffine.xfm,1] \
-n GenericLabel --verbose \
-o ${tmpdir}/mask.mnc

ImageMath 3 ${tmpdir}/weight.mnc m ${tmpdir}/otsu.mnc ${tmpdir}/mask.mnc

N4BiasFieldCorrection -d 3 -i ${tmpdir}/denoise.mnc -b [30] -c [300x300x300,1e-5] -r 0 -w ${tmpdir}/weight.mnc -x ${tmpdir}/initmask.mnc \
-o ${output} -s 4 --verbose

rm -rf ${tmpdir}