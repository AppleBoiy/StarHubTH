"""Shared constants for build_app.py, run_tests.py, and release.py.

Kept in one place so the app name, bundle name, and deployment target can't
drift out of sync across the three scripts that each need them.
"""

APP_NAME = "StarHubTH"
APP_DIR = f"{APP_NAME}.app"
TARGET_TRIPLE = "arm64-apple-macos13.0"
