#!/usr/bin/env python3
"""
Deploy compiled release artifacts to Miptgram API and MinIO storage,
and register them in the PostgreSQL database.
Can be executed in GitHub Actions or locally.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid


def post_multipart(url, file_path, fields, headers):
    boundary = f"----WebKitFormBoundary{uuid.uuid4().hex}"
    body = bytearray()

    # Add text fields
    for name, value in fields.items():
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode("utf-8"))
        body.extend(f"{value}\r\n".encode("utf-8"))

    # Add file
    file_name = os.path.basename(file_path)
    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(f'Content-Disposition: form-data; name="file"; filename="{file_name}"\r\n'.encode("utf-8"))
    body.extend(b"Content-Type: application/octet-stream\r\n\r\n")
    with open(file_path, "rb") as f:
        body.extend(f.read())
    body.extend(b"\r\n")

    body.extend(f"--{boundary}--\r\n".encode("utf-8"))

    req_headers = dict(headers)
    req_headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    req_headers["Content-Length"] = str(len(body))

    req = urllib.request.Request(url, data=bytes(body), headers=req_headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read().decode("utf-8")
            return json.loads(data), resp.status
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        return {"error": f"HTTP {e.code}: {err_body}"}, e.code
    except Exception as e:
        return {"error": str(e)}, 500


def post_json(url, payload, headers):
    body = json.dumps(payload).encode("utf-8")
    req_headers = dict(headers)
    req_headers["Content-Type"] = "application/json"
    req_headers["Content-Length"] = str(len(body))

    req = urllib.request.Request(url, data=body, headers=req_headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read().decode("utf-8")
            return json.loads(data), resp.status
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        return {"error": f"HTTP {e.code}: {err_body}"}, e.code
    except Exception as e:
        return {"error": str(e)}, 500


def main():
    parser = argparse.ArgumentParser(description="Upload and register releases in Miptgram API.")
    parser.add_argument("--artifacts-dir", required=True, help="Directory containing release files.")
    parser.add_argument("--api-url", default=None, help="Miptgram API base URL.")
    parser.add_argument("--admin-secret", default=None, help="Miptgram admin secret key.")
    parser.add_argument("--version", required=True, help="Release version (e.g. 1.0.1).")
    parser.add_argument("--build-number", type=int, required=True, help="Release build number.")
    parser.add_argument("--channel", default="stable", choices=["stable", "beta", "alpha"], help="Release channel.")
    parser.add_argument("--release-notes-file", default=None, help="Path to changelog / release notes file.")
    parser.add_argument("--force-update", action="store_true", help="Mark release as mandatory force update.")
    parser.add_argument("--strict", action="store_true", help="Fail if secrets are missing.")

    args = parser.parse_args()

    api_url = (args.api_url or os.environ.get("MIPTGRAM_API_URL") or "https://api.miptgram.ru").rstrip("/")
    admin_secret = args.admin_secret or os.environ.get("MIPTGRAM_ADMIN_SECRET") or ""

    if not admin_secret:
        msg = "[Deploy] WARNING: MIPTGRAM_ADMIN_SECRET is not configured. Skipping deployment to Miptgram API."
        if args.strict:
            print(msg, file=sys.stderr)
            sys.exit(1)
        else:
            print(msg)
            sys.exit(0)

    release_notes = ""
    if args.release_notes_file and os.path.exists(args.release_notes_file):
        try:
            with open(args.release_notes_file, "r", encoding="utf-8") as f:
                release_notes = f.read().strip()
        except Exception as e:
            print(f"[Deploy] Warning: could not read release notes: {e}")

    if not os.path.isdir(args.artifacts_dir):
        print(f"[Deploy] Error: artifacts directory not found: {args.artifacts_dir}", file=sys.stderr)
        sys.exit(1)

    # Collect distribution files
    valid_exts = (".apk", ".zip", ".tar.gz", ".exe", ".msix", ".dmg", ".deb", ".rpm", ".appimage")
    files_to_deploy = []
    for root, _, files in os.walk(args.artifacts_dir):
        for f in files:
            lower = f.lower()
            if any(lower.endswith(ext) for ext in valid_exts):
                files_to_deploy.append(os.path.join(root, f))

    if not files_to_deploy:
        print(f"[Deploy] No release files found in {args.artifacts_dir}")
        sys.exit(0)

    print(f"[Deploy] Found {len(files_to_deploy)} file(s) to upload & deploy to {api_url}:")
    for f in files_to_deploy:
        print(f"  • {os.path.basename(f)}")

    headers = {
        "X-Admin-Secret": admin_secret,
        "User-Agent": "Miptgram-Release-Deployer/1.0"
    }

    success_count = 0
    fail_count = 0

    for file_path in sorted(files_to_deploy):
        fname = os.path.basename(file_path)
        fsize = os.path.getsize(file_path)
        print(f"\n[Deploy] Processing {fname} ({fsize} bytes)...")

        # 1. Upload release binary to MinIO via API
        upload_endpoint = f"{api_url}/api/admin/upload-release"
        fields = {"channel": args.channel}
        
        upload_res, status = post_multipart(upload_endpoint, file_path, fields, headers)
        if status != 200 or not upload_res.get("success"):
            print(f"[Deploy] ❌ Failed to upload {fname}: {upload_res}", file=sys.stderr)
            fail_count += 1
            continue

        download_url = upload_res.get("download_url")
        platform = upload_res.get("platform") or upload_res.get("detected_platform") or "android"
        arch = upload_res.get("architecture") or upload_res.get("detected_architecture") or "universal"
        sha256 = upload_res.get("sha256") or ""
        size_bytes = upload_res.get("size_bytes") or upload_res.get("file_size_bytes") or fsize

        print(f"[Deploy] ✅ Uploaded successfully: {download_url}")
        print(f"[Deploy] Metadata: Platform={platform}, Arch={arch}, Channel={args.channel}, Size={size_bytes}")

        # 2. Register release in DB
        version_endpoint = f"{api_url}/api/admin/version"
        version_payload = {
            "platform": platform,
            "architecture": arch,
            "channel": args.channel,
            "latest_version": args.version,
            "latest_build": args.build_number,
            "min_supported_build": 1,
            "force_update": args.force_update,
            "download_url": download_url,
            "apk_size_bytes": size_bytes,
            "sha256": sha256,
            "release_notes": release_notes
        }

        ver_res, ver_status = post_json(version_endpoint, version_payload, headers)
        if ver_status != 200 or not ver_res.get("success"):
            print(f"[Deploy] ❌ Failed to register {platform}/{arch}/{args.channel} in database: {ver_res}", file=sys.stderr)
            fail_count += 1
            continue

        print(f"[Deploy] ✅ Registered in database successfully!")
        success_count += 1

    print(f"\n[Deploy] Deployment finished. Successful: {success_count}, Failed: {fail_count}")
    if fail_count > 0 and args.strict:
        sys.exit(1)


if __name__ == "__main__":
    main()
