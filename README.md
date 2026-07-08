# video2robot

End-to-end pipeline: **Video (or webcam) → Human pose → Robot motion**

```
[Video] → PromptHMR → [SMPL-X] → GMR → [robot_motion.pkl]
```

## Demo

<p align="center">
<video src="https://github.com/user-attachments/assets/a0f1bfb1-7e06-4672-8f6a-320ab60b0bfe" width="800" controls></video>
</p>

---

## Quick start (Windows + WSL + webcam → G1)

This repo is set up to **record on Windows** and **run the GPU pipeline in WSL2**.

### Prerequisites

| Component | Notes |
|-----------|--------|
| Windows 10/11 + WSL2 | Ubuntu recommended |
| NVIDIA GPU in WSL | CUDA visible via `nvidia-smi` in WSL |
| Miniconda in WSL | `gmr` and `phmr` conda envs |
| Python on Windows | For webcam recording (`opencv-python`) |
| SMPL-X models | One-time download (registration required) |

### 1. Clone and init submodules

```powershell
git clone --recursive https://github.com/AIM-Intelligence/video2robot.git
cd video2robot
# or after a plain clone:
git submodule update --init --recursive
```

### 2. WSL setup (one time)

In WSL:

```bash
cd /mnt/d/python/video2robot   # adjust drive/path if needed
bash scripts/setup_wsl.sh
```

This creates `gmr` and `phmr` envs, installs GMR + PromptHMR, ffmpeg, and symlinks SMPL-X into GMR.

### 3. Download SMPL-X (one time)

Register at [SMPL-X](https://smpl-x.is.tue.mpg.de/), then in WSL:

```bash
cd /mnt/d/python/video2robot/third_party/PromptHMR
bash scripts/fetch_smplx.sh
```

If extraction fails (no `unzip`), use the Python helper instead:

```bash
python /mnt/d/python/video2robot/scripts/extract_smplx.py
```

Verify models exist:

```bash
ls third_party/PromptHMR/data/body_models/smplx/SMPLX_NEUTRAL.*
```

### 4. Record + run pipeline (Windows PowerShell)

From the repo root:

```powershell
cd D:\python\video2robot

# Record 5s webcam → pose → G1 motion → browser viewer
.\scripts\webcam_to_g1.ps1 -Duration 5

# Pipeline only (no viewer)
.\scripts\webcam_to_g1.ps1 -Duration 5 -SkipViz

# Use an existing video
.\scripts\webcam_to_g1.ps1 -Video D:\python\video2robot\data\my_clip.mp4 -SkipRecord

# Custom project name
.\scripts\webcam_to_g1.ps1 -Duration 5 -Name my_dance
```

Each run creates a timestamped project under `data/run_YYYYMMDD_HHMMSS/` (or your `-Name`).

**Pose extraction takes ~10–85 min on GPU** and may look idle — that is normal.

### 5. View results

Open the URL printed in the terminal (use **`http://`**, not `https://`):

```powershell
# Pose check (human mesh + video)
wsl bash -lc "source ~/miniconda3/etc/profile.d/conda.sh && cd /mnt/d/python/video2robot && conda run -n phmr python scripts/visualize.py --project /mnt/d/python/video2robot/data/run_YYYYMMDD_HHMMSS --pose"

# Robot + video overlay (browser)
wsl bash -lc "source ~/miniconda3/etc/profile.d/conda.sh && cd /mnt/d/python/video2robot && conda run -n phmr python scripts/visualize.py --project /mnt/d/python/video2robot/data/run_YYYYMMDD_HHMMSS --robot-viser --robot-type unitree_g1"
```

### 6. Health check

```bash
conda run -n gmr python scripts/diagnose_project.py --project data/run_YYYYMMDD_HHMMSS
```

Checks video vs pose vs robot frame counts and flags stale cache issues.

---

## Project output

After a successful run, `data/<project>/` contains:

| File | Description |
|------|-------------|
| `original.mp4` | Input video |
| `results.pkl` | PromptHMR pose cache |
| `smplx_track_*.npz` | Per-person SMPL-X tracks |
| `robot_motion.pkl` | G1 motion (29 DOF) |
| `robot_motion_twist.pkl` | TWIST-compatible 23 DOF |
| `world4d.glb` | 3D scene export |

### `robot_motion.pkl` format

```python
{
    "fps": 30.0,
    "robot_type": "unitree_g1",
    "num_frames": N,
    "root_pos": np.ndarray,    # (N, 3)
    "root_rot": np.ndarray,    # (N, 4) quaternion xyzw
    "dof_pos": np.ndarray,     # (N, 29)
}
```

### Export CSV (BeyondMimic / UniStore reference motion)

```bash
conda run -n gmr python third_party/GMR/scripts/batch_gmr_pkl_to_csv.py \
  --folder /mnt/d/python/video2robot/data/<project>
```

Output: `data/<project>/csv/robot_motion.csv` — columns: `root_pos(3) + root_rot(4) + dof_pos(29)`.

---

## Manual pipeline (WSL or Linux)

Scripts auto-switch between `phmr` (pose) and `gmr` (retargeting) conda envs.

```bash
# Full pipeline from video
conda run -n gmr python scripts/run_pipeline.py \
  --video /path/to/video.mp4 \
  --static-camera \
  --robot unitree_g1 \
  --name my_project \
  --force

# From AI-generated video (needs API key in .env)
conda run -n gmr python scripts/run_pipeline.py \
  --action "Action sequence: The subject walks forward with four steps."

# Resume / re-run existing project
conda run -n gmr python scripts/run_pipeline.py --project data/my_project --force

# Individual steps
conda run -n phmr python scripts/extract_pose.py --project data/my_project --force
conda run -n gmr python scripts/convert_to_robot.py --project data/my_project --robot unitree_g1
```

### WSL-only bash shortcut

```bash
bash scripts/webcam_to_g1.sh /mnt/d/python/video2robot/data/webcam_20260707_112800.mp4
```

### Record webcam (Windows)

```powershell
python scripts/record_webcam.py --output data/webcam_test.mp4 --duration 8 --camera 0
```

Press `q` to stop early.

---

## Standard installation (Linux / native)

Requires **two conda environments**: `gmr` and `phmr`.

### GMR environment (robot retargeting)

```bash
conda create -n gmr python=3.10 -y
conda activate gmr
pip install -e .
pip install -e third_party/GMR
```

See [GMR README](third_party/GMR/README.md).

### PromptHMR environment (pose extraction)

**Blackwell GPU (sm_120):**

```bash
conda create -n phmr python=3.11 -y
conda activate phmr
cd third_party/PromptHMR
bash scripts/install_blackwell.sh
```

**Other GPUs (Ampere, Hopper, etc.):**

```bash
conda create -n phmr python=3.10 -y
conda activate phmr
cd third_party/PromptHMR
pip install -e .
```

See [PromptHMR README](third_party/PromptHMR/README.md).

### API keys (optional — for Veo/Sora video generation)

```bash
cp .env.example .env
# Add GOOGLE_API_KEY=... and/or OPENAI_API_KEY=...
```

---

## Visualization options

```bash
python scripts/visualize.py --project data/<project>              # list files
python scripts/visualize.py --project data/<project> --pose       # human pose (browser)
python scripts/visualize.py --project data/<project> --robot-viser  # robot + video (browser)
python scripts/visualize.py --project data/<project> --robot      # MuJoCo viewer
python scripts/visualize.py --project data/<project> --robot-viser --robot-track 1
```

On WSL, prefer **`--robot-viser`** (browser) over MuJoCo GUI — WSLg can hang.

---

## Web UI

```bash
uvicorn web.app:app --host 0.0.0.0 --port 8000
# http://localhost:8000
```

---

## Supported robots

| Robot | ID | DOF |
|-------|-----|-----|
| Unitree G1 | `unitree_g1` | 29 |
| Unitree H1 | `unitree_h1` | 19 |
| Booster T1 | `booster_t1` | 23 |

Full list: [GMR README](third_party/GMR/README.md)

---

## Troubleshooting

### SMPL-X missing

```bash
cd third_party/PromptHMR && bash scripts/fetch_smplx.sh
# or: python scripts/extract_smplx.py
```

### Stale pose cache (robot doesn't match video)

Re-run with `--force` or use a fresh project name. `webcam_to_g1.ps1` does this automatically.

### `ffprobe` permission denied in WSL

Windows ffmpeg on PATH can conflict. Use conda ffmpeg in `phmr`:

```bash
conda activate phmr && conda install -c conda-forge ffmpeg -y
```

### PromptHMR detects 3 people

Usually false positives. Pick the largest track:

```bash
python scripts/visualize.py --project data/<project> --robot-viser --robot-track 1
```

### Pose frames < video frames

Stay in frame for the whole clip. PromptHMR drops frames when detection fails.

### Browser viewer WebSocket errors

Open the printed URL with **`http://127.0.0.1:PORT`**, not `https://`.

### GMR betas mismatch

This repo patches GMR to use `num_betas=10`. If you see SMPL-X shape errors, confirm the patch in `third_party/GMR/general_motion_retargeting/utils/smpl.py`.

### Windows native GMR install fails

Use WSL for the full pipeline. GMR's `proxsuite` dependency often fails to build on Windows.

---

## Downstream use

| Target | Input | Notes |
|--------|-------|-------|
| MuJoCo / viser | `robot_motion.pkl` | Built-in visualization |
| BeyondMimic | GMR CSV | Train tracking policy |
| UniStore (Unitree app store) | CSV + trained MNN policy | Needs full app package, not CSV alone |
| Isaac GR00T | LeRobot parquet | Different format entirely |
| Real G1 | SDK2 / mimic policy | No direct pkl → robot playback in this repo |

---

## Project structure

```
video2robot/
├── video2robot/           # Main package
│   ├── pose/              # PromptHMR wrapper
│   ├── robot/             # GMR retargeter
│   └── visualization/     # Robot viser viewer
├── scripts/
│   ├── run_pipeline.py    # Full pipeline
│   ├── record_webcam.py   # Windows webcam capture
│   ├── webcam_to_g1.ps1   # Windows one-shot workflow
│   ├── webcam_to_g1.sh    # WSL bash variant
│   ├── setup_wsl.sh       # WSL environment setup
│   ├── diagnose_project.py
│   └── visualize.py
├── data/                  # Projects (gitignored)
└── third_party/
    ├── PromptHMR/
    └── GMR/
```

---

## License

- **video2robot**: MIT
- **[GMR](third_party/GMR/LICENSE)**: MIT
- **[PromptHMR](third_party/PromptHMR/LICENSE)**: Non-Commercial Scientific Research Use Only

Using PromptHMR end-to-end inherits its non-commercial restriction. Commercial use requires permission from the PromptHMR authors.

## Acknowledgements

- [PromptHMR](https://github.com/yufu-wang/PromptHMR) — 3D human mesh recovery
- [GMR](https://github.com/YanjieZe/GMR) — general motion retargeting
