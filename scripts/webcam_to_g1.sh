#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/webcam_to_g1.sh <video.mp4>"
  echo "Example: bash scripts/webcam_to_g1.sh /mnt/d/python/video2robot/data/webcam_20260707_112800.mp4"
  exit 1
fi

VIDEO="$1"
ROOT="/mnt/d/python/video2robot"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
cd "$ROOT"

if [ ! -f "$VIDEO" ]; then
  echo "Video not found: $VIDEO"
  exit 1
fi

echo "=== Running pipeline: video -> pose -> G1 motion ==="
conda run --no-capture-output -n gmr python scripts/run_pipeline.py \
  --video "$VIDEO" \
  --static-camera \
  --robot unitree_g1 \
  --name webcam_run \
  --force

PROJECT="$ROOT/data/webcam_run"

echo "=== MuJoCo visualization ==="
conda run --no-capture-output -n gmr python scripts/visualize.py \
  --project "$PROJECT" \
  --robot \
  --robot-type unitree_g1
