#!/usr/bin/env python3
"""Quick health check for a video2robot project."""

import argparse
import json
import pickle
import sys
from pathlib import Path

import cv2
import joblib
import numpy as np

sys.path.insert(0, str(Path(__file__).parent.parent))


def main() -> int:
    parser = argparse.ArgumentParser(description="Diagnose video2robot project sync/quality")
    parser.add_argument("--project", "-p", required=True)
    args = parser.parse_args()

    project = Path(args.project)
    if not project.exists():
        print(f"Missing project: {project}")
        return 1

    print(f"Project: {project}\n")

    video = project / "original.mp4"
    if video.exists():
        cap = cv2.VideoCapture(str(video))
        vf = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        vfps = float(cap.get(cv2.CAP_PROP_FPS) or 30.0)
        w, h = int(cap.get(3)), int(cap.get(4))
        cap.release()
        print(f"Video: {vf} frames @ {vfps:.1f} fps ({w}x{h}) = {vf/vfps:.1f}s")
    else:
        print("Video: MISSING")
        vf = 0

    results_pkl = project / "results.pkl"
    if not results_pkl.exists():
        print("Pose: MISSING (results.pkl)")
        return 1

    results = joblib.load(results_pkl)
    people = results.get("people", {})
    cam = results.get("camera_world", results.get("camera", {}))
    cam_n = len(cam.get("Rwc", [])) if cam.get("Rwc") is not None else 0
    print(f"Pose tracks: {len(people)} | camera frames: {cam_n}")

    for key, person in people.items():
        frames = np.asarray(person.get("frames", []))
        bb = person.get("bboxes")
        area = 0.0
        if bb is not None and len(bb):
            b = np.asarray(bb)
            if b.ndim == 2 and b.shape[1] >= 4:
                area = float(np.nanmedian((b[:, 2] - b[:, 0]) * (b[:, 3] - b[:, 1])))
        nf = len(frames)
        span = f"{frames.min()}-{frames.max()}" if nf else "n/a"
        print(f"  track {key}: {nf} frames [{span}] bbox_area={area:.0f}")

    robot_pkl = project / "robot_motion.pkl"
    if robot_pkl.exists():
        rm = pickle.load(open(robot_pkl, "rb"))
        rp = rm["root_pos"]
        travel = float(np.linalg.norm(rp[-1] - rp[0]))
        print(
            f"Robot: {rm['num_frames']} frames @ {rm['fps']} fps | "
            f"root travel {travel:.2f}m | dof std {rm['dof_pos'].std():.3f}"
        )
    else:
        print("Robot: MISSING")

    print()
    if vf and cam_n and vf > cam_n:
        print(f"ISSUE: video has {vf} frames but pose/camera only {cam_n}.")
        print("  -> Viewer sync breaks after frame", cam_n - 1)
        print("  -> Re-record staying in frame, or trim video to first", cam_n, "frames")
    if len(people) > 1:
        print("NOTE: multiple tracks detected. Try --robot-track 2 or 3 in viewer.")
    if robot_pkl.exists():
        rm = pickle.load(open(robot_pkl, "rb"))
        if rm["dof_pos"].std() < 0.15:
            print("NOTE: very small robot motion — pose may be weak or subject mostly still.")

    meta = project / "smplx_tracks.json"
    if meta.exists():
        best = json.load(open(meta)).get("best_track_index")
        print(f"Best track (auto): {best}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
