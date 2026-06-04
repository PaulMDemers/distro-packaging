#!/usr/bin/env python3
"""Write a machine-readable inventory for built ISO artifacts."""

from __future__ import annotations

import csv
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path.cwd()
PROFILE_INFO = ["bash", "scripts/common/profile-info.sh"]
REGISTRY = ROOT / "configs" / "profiles.tsv"
SPINS_DIR = ROOT / "configs" / "spins"
VERIFY_SHA256 = os.environ.get("MANIFEST_VERIFY_SHA256") == "1"


def profile_field(profile_id: str, field: str) -> str:
    result = subprocess.run(
        [*PROFILE_INFO, profile_id, field],
        check=True,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
    )
    return result.stdout.rstrip("\n")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_sha256(path: Path) -> str | None:
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8", errors="replace").strip()
    if not text:
        return None
    return text.split()[0]


def candidate_logs(*paths: str) -> list[Path]:
    candidates: list[Path] = []
    for raw_path in paths:
        if not raw_path:
            continue
        path = Path(raw_path)
        candidates.append(ROOT / path)
        candidates.append(ROOT / "dist" / "test" / path.name)
        candidates.append(ROOT / "dist" / "images" / path.name)

    unique: list[Path] = []
    seen: set[Path] = set()
    for path in candidates:
        resolved = path.resolve(strict=False)
        if resolved not in seen:
            unique.append(path)
            seen.add(resolved)
    return unique


def marker_status(marker: str, logs: list[Path]) -> dict[str, object]:
    existing_logs = [path for path in logs if path.exists()]
    if not marker:
        return {"status": "not_configured", "marker": marker, "logs": [str(p) for p in existing_logs]}

    for path in existing_logs:
        if marker in path.read_text(encoding="utf-8", errors="ignore"):
            return {
                "status": "passed",
                "marker": marker,
                "log": str(path),
                "logs": [str(p) for p in existing_logs],
            }

    if existing_logs:
        return {"status": "failed", "marker": marker, "logs": [str(p) for p in existing_logs]}

    return {"status": "missing", "marker": marker, "logs": []}


def directory_size(path: Path) -> int:
    total = 0
    for item in path.rglob("*"):
        if item.is_file():
            total += item.stat().st_size
    return total


def repository_manifest() -> dict[str, object]:
    repo_root = ROOT / "dist" / "repo"
    suite = os.environ.get("REPO_SUITE", "custom")
    component = os.environ.get("REPO_COMPONENT", "main")
    packages_index = repo_root / "dists" / suite / component / "binary-amd64" / "Packages"
    release_file = repo_root / "dists" / suite / "Release"

    debs = []
    for deb in sorted((repo_root / "pool").rglob("*.deb")) if repo_root.exists() else []:
        debs.append(
            {
                "path": str(deb.relative_to(ROOT)),
                "size_bytes": deb.stat().st_size,
                "sha256": sha256_file(deb),
            }
        )

    return {
        "path": str(repo_root.relative_to(ROOT)),
        "exists": repo_root.exists(),
        "suite": suite,
        "component": component,
        "packages_index": str(packages_index.relative_to(ROOT)),
        "packages_index_exists": packages_index.exists(),
        "release_file": str(release_file.relative_to(ROOT)),
        "release_file_exists": release_file.exists(),
        "deb_count": len(debs),
        "debs": debs,
        "size_bytes": directory_size(repo_root) if repo_root.exists() else 0,
    }


def spin_spec_manifest(profile_id: str) -> dict[str, object]:
    path = SPINS_DIR / f"{profile_id}.toml"
    artifact: dict[str, object] = {
        "path": str(path.relative_to(ROOT)),
        "exists": path.exists(),
    }
    if path.exists():
        artifact["size_bytes"] = path.stat().st_size
        artifact["sha256"] = sha256_file(path)
    return artifact


def main() -> int:
    if not REGISTRY.exists():
        print(f"missing registry: {REGISTRY}", file=sys.stderr)
        return 1

    profiles: list[dict[str, object]] = []
    with REGISTRY.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            profile_id = row["id"]
            iso = ROOT / profile_field(profile_id, "iso")
            sha_path = ROOT / profile_field(profile_id, "sha256")
            serial_log = profile_field(profile_id, "serial_log")
            boot_serial_log = profile_field(profile_id, "boot_serial_log")
            marker = profile_field(profile_id, "boot_marker")

            sha_recorded = read_sha256(sha_path)
            sha_verified = False
            if iso.exists() and (VERIFY_SHA256 or not sha_recorded):
                sha_actual = sha256_file(iso)
                sha_verified = True
            else:
                sha_actual = sha_recorded if iso.exists() else None
            base_alias = profile_field(profile_id, "base_alias")
            base_iso = profile_field(profile_id, "base_iso")
            base_iso_path = ROOT / base_iso if base_iso else None

            test_logs = (
                candidate_logs(boot_serial_log)
                if row["kind"] == "autoinstall"
                else candidate_logs(serial_log, boot_serial_log)
            )

            artifact: dict[str, object] = {
                "id": profile_id,
                "family": row["family"],
                "kind": row["kind"],
                "description": row["description"],
                "profile_dir": row["profile_dir"],
                "spin_spec": spin_spec_manifest(profile_id),
                "image_name": profile_field(profile_id, "image_name"),
                "metapackages": profile_field(profile_id, "metapackages").split(),
                "iso": str(iso.relative_to(ROOT)),
                "exists": iso.exists(),
                "sha256": sha_actual,
                "sha256_recorded": sha_recorded,
                "sha256_matches_record": bool(sha_actual and sha_recorded and sha_actual == sha_recorded),
                "sha256_verified": sha_verified,
                "sha256_file": str(sha_path.relative_to(ROOT)),
                "base_alias": base_alias or None,
                "base_iso": base_iso or None,
                "base_iso_exists": bool(base_iso_path and base_iso_path.exists()),
                "test": marker_status(marker, test_logs),
            }

            if iso.exists():
                stat = iso.stat()
                artifact["size_bytes"] = stat.st_size
                artifact["size_mib"] = round(stat.st_size / 1024 / 1024, 2)
                artifact["modified_at"] = datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat()
            else:
                artifact["size_bytes"] = None
                artifact["size_mib"] = None
                artifact["modified_at"] = None

            profiles.append(artifact)

    manifest = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "workspace": str(ROOT),
        "repository": repository_manifest(),
        "profiles": profiles,
    }

    out_path = ROOT / "dist" / "manifest.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
