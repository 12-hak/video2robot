#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/d/python/video2robot/third_party/PromptHMR"
cd "$ROOT"

if ! command -v unzip >/dev/null 2>&1; then
  echo "Installing unzip..."
  sudo apt-get update -qq
  sudo apt-get install -y unzip
fi

ZIP="data/body_models/smplx.zip"
DEST="data/body_models/smplx"

if [ -f "$DEST/SMPLX_NEUTRAL.pkl" ] || [ -f "$DEST/SMPLX_NEUTRAL.npz" ]; then
  echo "SMPL-X already extracted at $DEST"
  exit 0
fi

if [ ! -f "$ZIP" ]; then
  echo "Missing $ZIP"
  echo "Re-download with:"
  echo "  cd $ROOT && bash scripts/fetch_smplx.sh"
  exit 1
fi

mkdir -p "$DEST"
unzip -o "$ZIP" -d "$DEST"
mv "$DEST"/models/smplx/* "$DEST"/
rm -rf "$DEST/models" "$ZIP"
echo "SMPL-X ready at $DEST"
