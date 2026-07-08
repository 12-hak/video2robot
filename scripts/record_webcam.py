#!/usr/bin/env python3
"""Record webcam video for the video2robot pipeline."""

import argparse
import sys
import time
from datetime import datetime
from pathlib import Path

import cv2


def main():
    parser = argparse.ArgumentParser(description="Record webcam video for video2robot")
    parser.add_argument("--output", "-o", type=Path, help="Output .mp4 path")
    parser.add_argument("--duration", "-d", type=float, default=8.0, help="Recording length in seconds")
    parser.add_argument("--camera", "-c", type=int, default=0, help="Webcam device index")
    parser.add_argument("--width", type=int, default=1280, help="Frame width")
    parser.add_argument("--height", type=int, default=720, help="Frame height")
    parser.add_argument("--fps", type=int, default=30, help="Target FPS")
    args = parser.parse_args()

    if args.output is None:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        args.output = Path(__file__).resolve().parent.parent / "data" / f"webcam_{stamp}.mp4"

    args.output.parent.mkdir(parents=True, exist_ok=True)

    cap = cv2.VideoCapture(args.camera, cv2.CAP_DSHOW)
    if not cap.isOpened():
        cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        print(f"Error: could not open camera {args.camera}", file=sys.stderr)
        return 1

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, args.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
    cap.set(cv2.CAP_PROP_FPS, args.fps)

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or args.fps

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(args.output), fourcc, fps, (width, height))
    if not writer.isOpened():
        print("Error: could not create video writer", file=sys.stderr)
        cap.release()
        return 1

    print(f"Recording {args.duration:.1f}s from camera {args.camera} -> {args.output}")
    print("Press 'q' to stop early.")

    start = time.time()
    frames = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            print("Error: failed to read frame", file=sys.stderr)
            break

        writer.write(frame)
        frames += 1
        cv2.imshow("Recording (q to stop)", frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break
        if time.time() - start >= args.duration:
            break

    cap.release()
    writer.release()
    cv2.destroyAllWindows()

    elapsed = max(time.time() - start, 1e-6)
    print(f"Saved {frames} frames ({frames / elapsed:.1f} fps) to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
