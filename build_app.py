#!/usr/bin/env python3
import os
import shutil
import subprocess
import json
import sys

from build_config import APP_NAME, APP_DIR, TARGET_TRIPLE

CONTENTS_DIR = os.path.join(APP_DIR, "Contents")
MACOS_DIR = os.path.join(CONTENTS_DIR, "MacOS")
RESOURCES_DIR = os.path.join(CONTENTS_DIR, "Resources")
SUPPORTED_LOCALES = {
    "en": "Centralized English Localization Strings",
    "th": "Centralized Thai Localization Strings",
}

def strings_escape(value):
    return (
        value
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
    )

def generate_localizable_strings():
    locale_data = {}
    for locale in SUPPORTED_LOCALES:
        json_path = os.path.join("assets", f"{locale}.json")
        with open(json_path, "r", encoding="utf-8") as file:
            locale_data[locale] = json.load(file)

    key_sets = {locale: set(values.keys()) for locale, values in locale_data.items()}
    reference_locale = "en"
    reference_keys = key_sets[reference_locale]
    for locale, keys in key_sets.items():
        missing = sorted(reference_keys - keys)
        extra = sorted(keys - reference_keys)
        if missing or extra:
            if missing:
                print(f"[ERROR] {locale}.json is missing keys: {', '.join(missing)}")
            if extra:
                print(f"[ERROR] {locale}.json has extra keys: {', '.join(extra)}")
            raise SystemExit(1)

    for locale, values in locale_data.items():
        lproj_dir = os.path.join("assets", f"{locale}.lproj")
        os.makedirs(lproj_dir, exist_ok=True)
        strings_path = os.path.join(lproj_dir, "Localizable.strings")
        with open(strings_path, "w", encoding="utf-8") as file:
            file.write(f"/* {SUPPORTED_LOCALES[locale]} */\n")
            for key, value in values.items():
                file.write(f'"{strings_escape(key)}" = "{strings_escape(value)}";\n')
        print(f"[INFO] Generated {strings_path}")

def concurrency_check_flags():
    """Return the strictest concurrency-diagnostic flags this swiftc accepts.

    Refactor Phase 0.4 (docs/REFACTOR_PLAN.md) added `-strict-concurrency=complete` when
    the codebase relied on ~65 hand-written DispatchQueue.main.async hops for main-thread
    correctness with no @MainActor annotations, so the compiler couldn't see a missed hop.
    Phase 5 (5.1-5.6: async/await conversion, Sendable conformance, 5.3: @MainActor on
    every store) burned that warning count to zero, so as of 5.7 the codebase compiles
    clean under full Swift 6 language mode (`-swift-version 6`, verified directly) — try
    that first, since it makes every one of these diagnostics a hard error instead of a
    warning, closing the gap the plain warning flag left open.

    The spelling/strength of these flags changed across Swift releases (-warn-concurrency
    was superseded by -strict-concurrency=, itself superseded by full -swift-version 6),
    and an unrecognised flag makes swiftc fail outright. So probe rather than assume, and
    degrade to no flags rather than break the build on an unexpected toolchain.
    """
    if os.environ.get("STARHUB_NO_CONCURRENCY_CHECKS"):
        return []

    candidates = [
        ["-swift-version", "6"],
        ["-strict-concurrency=complete"],
        ["-Xfrontend", "-strict-concurrency=complete"],
        ["-Xfrontend", "-warn-concurrency"],
    ]

    probe_dir = os.path.join(".build", "flag-probe")
    os.makedirs(probe_dir, exist_ok=True)
    probe_source = os.path.join(probe_dir, "probe.swift")
    with open(probe_source, "w", encoding="utf-8") as file:
        file.write("let probe = 0\n")

    for flags in candidates:
        probe = subprocess.run(
            ["swiftc", probe_source, "-typecheck", "-target", TARGET_TRIPLE] + flags,
            capture_output=True,
        )
        if probe.returncode == 0:
            print(f"[INFO] Concurrency checking enabled: {' '.join(flags)}")
            return flags

    print("[WARN] This swiftc accepts none of the known concurrency-check flags; continuing without.")
    return []

def run_standards_check():
    """Run scripts/check_standards.py (Refactor Phase 9.1/9.2).

    Warnings-only by default — see docs/REFACTOR_PLAN.md Phase 9. Set
    STARHUB_STANDARDS_STRICT=1 to promote findings to a build failure once
    the codebase is clean enough for that to be worth enforcing.
    """
    script_path = os.path.join("scripts", "check_standards.py")
    if not os.path.exists(script_path):
        return
    result = subprocess.run([sys.executable, script_path])
    if result.returncode != 0:
        print("[ERROR] check_standards.py failed under STARHUB_STANDARDS_STRICT.")
        raise SystemExit(1)

def create_app_bundle():
    print(f"[INFO] Starting build process for {APP_DIR}...")
    run_standards_check()
    generate_localizable_strings()

    # 1. Clean old build
    if os.path.exists(APP_DIR):
        shutil.rmtree(APP_DIR)
        
    # 2. Create directories
    os.makedirs(MACOS_DIR, exist_ok=True)
    os.makedirs(RESOURCES_DIR, exist_ok=True)
    
    # 3. Copy Info.plist and Generate Custom Assets
    if not os.path.exists("Info.plist"):
        print("[ERROR] Info.plist not found — cannot build without it.")
        return 1
    shutil.copy2("Info.plist", os.path.join(CONTENTS_DIR, "Info.plist"))

    print("[INFO] Using existing Custom Stardew UI Assets...")

    custom_ui_dir = "assets/custom_ui"
    if os.path.exists(custom_ui_dir):
        for img in os.listdir(custom_ui_dir):
            if img.endswith(".png"):
                shutil.copy2(os.path.join(custom_ui_dir, img), os.path.join(RESOURCES_DIR, img))
        print("[INFO] Copied Custom UI Assets to App Resources")
    else:
        print(f"[WARN] {custom_ui_dir} not found — skipping custom UI assets.")

    app_icon_path = "assets/AppIcon.icns"
    if os.path.exists(app_icon_path):
        shutil.copy2(app_icon_path, os.path.join(RESOURCES_DIR, "AppIcon.icns"))
        print("[INFO] Copied AppIcon.icns to App Resources")
    else:
        print(f"[WARN] {app_icon_path} not found — app bundle will have no icon.")

    changelog_path = "CHANGELOG.md"
    if os.path.exists(changelog_path):
        shutil.copy2(changelog_path, os.path.join(RESOURCES_DIR, "CHANGELOG.md"))
        print("[INFO] Copied CHANGELOG.md to App Resources")
    else:
        print(f"[WARN] {changelog_path} not found — skipping in-app changelog.")

    for lang in ["en.lproj", "th.lproj"]:
        lproj_src = os.path.join("assets", lang)
        if os.path.exists(lproj_src):
            lproj_dest = os.path.join(RESOURCES_DIR, lang)
            os.makedirs(lproj_dest, exist_ok=True)
            shutil.copy2(os.path.join(lproj_src, "Localizable.strings"), os.path.join(lproj_dest, "Localizable.strings"))
            print(f"[INFO] Copied {lang} to App Resources")
        else:
            print(f"[WARN] {lproj_src} not found — {lang} strings will be missing from the bundle.")

    # 4. Compile Swift App
    app_executable = os.path.join(MACOS_DIR, APP_NAME)
    module_cache_dir = os.path.join(".build", "module-cache")
    os.makedirs(module_cache_dir, exist_ok=True)
    
    # Find all Swift files recursively under StarHubTH
    swift_files = []
    for root, dirs, files in os.walk("StarHubTH"):
        for file in files:
            if file.endswith(".swift"):
                swift_files.append(os.path.join(root, file))
                
    if not swift_files:
        print("[ERROR] No Swift source files (.swift) found.")
        return 1

    print(f"[INFO] Compiling Swift code ({len(swift_files)} files)...")
    swiftc_cmd = ["swiftc"] + swift_files + [
        "-o", app_executable,
        "-parse-as-library",
        "-module-cache-path", module_cache_dir,
        "-target", TARGET_TRIPLE,
    ] + concurrency_check_flags()

    # Run compiler
    result = subprocess.run(swiftc_cmd)
    if result.returncode != 0:
        print("[ERROR] Swift compilation failed.")
        return 1

    # 5. Ad-hoc codesign to make it run locally without Gatekeeper blocking
    print("[INFO] Signing application (Codesign)...")
    codesign_cmd = ["codesign", "-s", "-", "-f", APP_DIR]
    codesign_result = subprocess.run(codesign_cmd)
    if codesign_result.returncode != 0:
        print("[ERROR] Codesign failed.")
        return 1

    print(f"[SUCCESS] Successfully built {APP_DIR}")
    print("[INFO] Run 'open StarHubTH.app' to launch the application.")
    return 0

if __name__ == "__main__":
    sys.exit(create_app_bundle())
