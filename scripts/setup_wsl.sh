#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/d/python/video2robot"
source "$HOME/miniconda3/etc/profile.d/conda.sh"

cd "$ROOT"

echo "=== video2robot WSL setup ==="

if ! command -v conda >/dev/null 2>&1; then
  echo "Conda not found. Install Miniconda in WSL first."
  exit 1
fi

if ! conda env list | grep -q '^gmr '; then
  echo "[1/4] Creating gmr env..."
  conda create -n gmr python=3.10 -y
fi

echo "[2/4] Installing video2robot + GMR into gmr env..."
conda activate gmr
pip install -e .
pip install -e "$ROOT/third_party/GMR"
pip install opencv-python fastapi uvicorn viser trimesh python-multipart aiofiles jinja2 openai

if ! conda env list | grep -q '^phmr '; then
  echo "[3/4] Creating phmr env..."
  conda create -n phmr python=3.11 -y
fi

echo "[4/4] Installing PromptHMR (world-video pipeline) into phmr env..."
conda activate phmr
cd "$ROOT/third_party/PromptHMR"
conda install -c conda-forge ffmpeg -y

pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu121
pip install --upgrade setuptools pip
pip install torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu121.html
conda install -c conda-forge suitesparse -y
pip install -r requirements.txt
pip install -e python_libs/chumpy --no-build-isolation
pip install -U xformers==0.0.27.post2 --index-url https://download.pytorch.org/whl/cu121 --no-deps

gdown --folder -O ./data/ https://drive.google.com/drive/folders/1IXyhVqL25ofI-tYqyUZCqF-h4V20795H?usp=sharing || true
pip install data/wheels/detectron2-0.8-cp311-cp311-linux_x86_64.whl || pip install 'git+https://github.com/facebookresearch/detectron2.git' --no-build-isolation
pip install data/wheels/droid_backends_intr-0.3-cp311-cp311-linux_x86_64.whl || true
pip install data/wheels/lietorch-0.3-cp311-cp311-linux_x86_64.whl || true
pip install data/wheels/sam2-1.5-cp311-cp311-linux_x86_64.whl || pip install sam2

sed -i 's/\r$//' scripts/fetch_data.sh scripts/fetch_smplx.sh 2>/dev/null || true
conda activate phmr
bash scripts/fetch_data.sh || true

mkdir -p "$ROOT/data"
mkdir -p "$ROOT/third_party/GMR/assets/body_models"
if [ -d "$ROOT/third_party/PromptHMR/data/body_models/smplx" ]; then
  ln -sfn "$ROOT/third_party/PromptHMR/data/body_models/smplx" "$ROOT/third_party/GMR/assets/body_models/smplx"
fi

cd "$ROOT"
echo
echo "Setup complete."
echo
echo "IMPORTANT: Download SMPL-X models (registration required):"
echo "  cd $ROOT/third_party/PromptHMR"
echo "  bash scripts/fetch_smplx.sh"
echo
echo "Then run:"
echo "  bash scripts/webcam_to_g1.sh /mnt/d/python/video2robot/data/your_video.mp4"
