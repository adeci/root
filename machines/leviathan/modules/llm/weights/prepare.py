#!/usr/bin/env python3

import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time
from urllib.parse import quote

CURL = "@curl@"


def log(message):
    print(message, flush=True)


def die(message):
    log(f"error: {message}")
    sys.exit(1)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb", buffering=0) as handle:
        while True:
            chunk = handle.read(64 * 1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def is_good_blob(path, expected_size):
    try:
        st = path.stat()
    except FileNotFoundError:
        return False
    return stat.S_ISREG(st.st_mode) and st.st_size == expected_size


def token_from_systemd():
    credentials_dir = os.environ.get("CREDENTIALS_DIRECTORY")
    if not credentials_dir:
        return None
    token_path = Path(credentials_dir) / "hf-token"
    if not token_path.exists():
        return None
    return token_path.read_text().strip() or None


def install_verified(src, dest, expected_hash, expected_size):
    if src.stat().st_size != expected_size:
        die(f"{src} has wrong size")
    log(f"hashing {src}")
    actual_hash = sha256_file(src)
    if actual_hash != expected_hash:
        return False

    tmp = dest.parent / f".{dest.name}.{os.getpid()}.tmp"
    tmp.unlink(missing_ok=True)
    os.replace(src, tmp)
    os.chmod(tmp, 0o444)
    os.replace(tmp, dest)
    log(f"installed {dest}")
    return True


def gib(bytes_count):
    return bytes_count / 1024 / 1024 / 1024


def download_file(repo, revision, relative_path, download_dir, token, expected_size):
    downloaded = download_dir / relative_path
    downloaded.parent.mkdir(parents=True, exist_ok=True)
    url = f"https://huggingface.co/{repo}/resolve/{revision}/{quote(relative_path, safe='/')}"

    cmd = [
        CURL,
        "--fail",
        "--location",
        "--continue-at",
        "-",
        "--silent",
        "--show-error",
        "--output",
        str(downloaded),
        url,
    ]
    stdin = None
    if token:
        cmd.extend(["--config", "-"])
        stdin = subprocess.PIPE

    started = time.monotonic()
    last_time = started
    last_size = downloaded.stat().st_size if downloaded.exists() else 0
    if last_size:
        log(f"resuming {downloaded}: {gib(last_size):.1f}/{gib(expected_size):.1f} GiB")

    proc = subprocess.Popen(cmd, stdin=stdin, text=True)
    if token and proc.stdin:
        proc.stdin.write(f'header = "Authorization: Bearer {token}"\n')
        proc.stdin.close()

    while proc.poll() is None:
        time.sleep(10)
        now = time.monotonic()
        size = downloaded.stat().st_size if downloaded.exists() else 0
        delta = size - last_size
        elapsed = max(now - last_time, 0.001)
        speed_mib = delta / 1024 / 1024 / elapsed
        pct = size * 100 / expected_size if expected_size else 0
        log(
            f"downloaded {downloaded.name}: "
            f"{gib(size):.1f}/{gib(expected_size):.1f} GiB "
            f"({pct:.1f}%, {speed_mib:.1f} MiB/s)"
        )
        last_time = now
        last_size = size

    if proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, cmd)

    if not downloaded.is_file():
        die(f"download finished but {downloaded} is missing")
    return downloaded


def expected_hashes(weights):
    return {
        spec["sha256"]
        for weight in weights.values()
        for spec in weight["files"].values()
    }


def rebuild_model_tree(base, weights):
    models = base / "models"
    tmp_models = base / f"models.tmp.{os.getpid()}"
    shutil.rmtree(tmp_models, ignore_errors=True)
    tmp_models.mkdir(parents=True)

    for weight_id, weight in weights.items():
        for relative_path, spec in weight["files"].items():
            link = tmp_models / weight_id / relative_path
            link.parent.mkdir(parents=True, exist_ok=True)
            target = base / "blobs" / "sha256" / spec["sha256"]
            link.symlink_to(target)

    shutil.rmtree(models, ignore_errors=True)
    os.replace(tmp_models, models)


def prune_blobs(base, weights):
    keep = expected_hashes(weights)
    blobs = base / "blobs" / "sha256"
    for blob in blobs.iterdir():
        if blob.is_file() and blob.name not in keep:
            log(f"pruning {blob}")
            blob.unlink()


def main():
    if len(sys.argv) != 2:
        die("usage: llm-weights-prepare MANIFEST")

    manifest = json.loads(Path(sys.argv[1]).read_text())
    base = Path(manifest["baseDir"])
    blobs = base / "blobs" / "sha256"
    downloads = base / "downloads"
    token = os.environ.get("HF_TOKEN") or token_from_systemd()

    for directory in [base, blobs, downloads]:
        directory.mkdir(parents=True, exist_ok=True)
        os.chmod(directory, 0o755)

    for weight_id, weight in manifest["weights"].items():
        repo = weight["source"]["repo"]
        revision = weight["source"]["revision"]
        log(f"checking {weight_id}: {weight['displayName']}")

        for relative_path, spec in weight["files"].items():
            expected_hash = spec["sha256"]
            expected_size = int(spec["size"])
            dest = blobs / expected_hash

            if is_good_blob(dest, expected_size):
                log(f"ok {weight_id}/{relative_path}: existing blob")
                continue

            log(f"downloading {weight_id}/{relative_path} from {repo}@{revision}")
            download_dir = downloads / expected_hash
            downloaded = download_file(
                repo, revision, relative_path, download_dir, token, expected_size
            )
            if not install_verified(downloaded, dest, expected_hash, expected_size):
                shutil.rmtree(download_dir, ignore_errors=True)
                die(f"downloaded {downloaded} hash mismatch")
            shutil.rmtree(download_dir, ignore_errors=True)

    rebuild_model_tree(base, manifest["weights"])
    prune_blobs(base, manifest["weights"])
    log(f"ready: {base / 'models'}")


if __name__ == "__main__":
    main()
