#!/usr/bin/env python3
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "third_party" / "PromptHMR" / "data" / "body_models"
ZIP = ROOT / "smplx.zip"
DEST = ROOT / "smplx"


def main() -> int:
    if (DEST / "SMPLX_NEUTRAL.pkl").exists() or (DEST / "SMPLX_NEUTRAL.npz").exists():
        print(f"SMPL-X already extracted at {DEST}")
        return 0

    if not ZIP.exists():
        print(f"Missing {ZIP}")
        print("Re-run fetch (login worked before; password was fine):")
        print("  wsl bash -c 'cd /mnt/d/python/video2robot/third_party/PromptHMR && bash scripts/fetch_smplx.sh'")
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    print(f"Extracting {ZIP} ...")
    with zipfile.ZipFile(ZIP) as zf:
        zf.extractall(DEST)

    nested = DEST / "models" / "smplx"
    if nested.exists():
        for item in nested.iterdir():
            target = DEST / item.name
            if target.exists():
                if target.is_dir():
                    shutil.rmtree(target)
                else:
                    target.unlink()
            shutil.move(str(item), str(target))
        shutil.rmtree(DEST / "models")

    ZIP.unlink()
    files = sorted(p.name for p in DEST.glob("SMPLX*"))
    print(f"SMPL-X ready at {DEST}")
    print("Files:", files[:5])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
