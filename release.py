#!/usr/bin/env python3
import os
import subprocess
import plistlib
import sys

from build_config import APP_NAME, APP_DIR

BUNDLES_DIR = "bundles"
UNKNOWN_VERSION = "0.0.0"

def get_version():
    plist_path = "Info.plist"
    if not os.path.exists(plist_path):
        return UNKNOWN_VERSION
    with open(plist_path, 'rb') as f:
        plist = plistlib.load(f)
        return plist.get("CFBundleShortVersionString", UNKNOWN_VERSION)

def create_release():
    print("[INFO] Starting release process...")

    # 1. Build the app using existing build_app.py
    print("[INFO] Building application...")
    result = subprocess.run([sys.executable, "build_app.py"])
    if result.returncode != 0:
        print("[ERROR] Application build failed. Check the errors above.")
        return 1

    if not os.path.exists(APP_DIR):
        print(f"[ERROR] Output folder {APP_DIR} not found after build.")
        return 1

    # 2. Get version
    version = get_version()
    print(f"[INFO] Current version: v{version}")

    # 3. Create bundles directory
    os.makedirs(BUNDLES_DIR, exist_ok=True)

    # 4. Zip the app
    zip_name = f"{APP_NAME}_v{version}"
    zip_path = os.path.join(BUNDLES_DIR, f"{zip_name}.zip")

    # Remove old zip if exists
    if os.path.exists(zip_path):
        os.remove(zip_path)

    print(f"[INFO] Archiving bundle to {zip_path}...")

    # We use ditto on macOS to preserve resource forks and codesignatures properly
    ditto_result = subprocess.run(["ditto", "-c", "-k", "--keepParent", APP_DIR, zip_path])
    if ditto_result.returncode != 0:
        print("[ERROR] Archiving with ditto failed.")
        return 1

    print("[SUCCESS] Release bundle created successfully.")
    print(f"[INFO] The bundle is ready at {zip_path}.")
    print("-" * 40)

    upload = input("[PROMPT] Do you want to upload this release to GitHub? (y/n): ")
    if upload.lower() in ['y', 'yes']:
        print("[INFO] Uploading release...")
        tag = f"v{version}"
        cmd = [
            "gh", "release", "create", tag, zip_path,
            "--title", f"Release {tag}",
            "--notes", f"Automated release for StarHubTH {tag}."
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            print(f"[SUCCESS] Uploaded {tag} successfully.")
            print(res.stdout.strip())
        else:
            print(f"[ERROR] Upload failed:\n{res.stderr.strip()}")
            return 1
    else:
        print("[INFO] Skipping upload.")

    return 0

if __name__ == "__main__":
    sys.exit(create_release())
