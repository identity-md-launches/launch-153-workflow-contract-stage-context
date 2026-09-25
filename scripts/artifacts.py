#!/usr/bin/env python3
"""Export/check compiler ABIs and verify all vendored dependency file hashes offline."""

import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check ABI exports without rewriting them")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent

    for dependency in json.loads((root / "docs/dependencies.json").read_text()):
        directory = root / dependency["path"]
        actual_files = {str(p.relative_to(directory)) for p in directory.rglob("*") if p.is_file()}
        if actual_files != set(dependency["files"]):
            raise SystemExit(f"Vendored file list differs: {directory}")
        for name, expected in dependency["files"].items():
            digest = hashlib.sha256((directory / name).read_bytes()).hexdigest()
            if digest != expected:
                raise SystemExit(f"Vendored checksum differs: {directory / name}")

    for name in ("SeatCompute", "ComputeProject"):
        artifact = root / "out" / f"{name}.sol" / f"{name}.json"
        if not artifact.exists():
            raise SystemExit(f"Missing {artifact}; run forge build first")
        abi = json.loads(artifact.read_text())["abi"]
        destination = root / "docs/abi" / f"{name}.json"
        if args.check:
            if not destination.exists() or json.loads(destination.read_text()) != abi:
                raise SystemExit(f"Stale ABI: {destination}; run python3 scripts/artifacts.py")
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(abi, indent=2) + "\n")
    print("ABI exports and vendored dependencies verified" if args.check else "ABI exports written; vendors verified")


if __name__ == "__main__":
    main()
