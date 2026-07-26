#!/usr/bin/env python3
"""Generates assets/{en,th}.lproj/Localizable.strings from assets/{en,th}.json.

Originally part of build_app.py, extracted (Xcode Migration Plan, Phase 0.1) so the
Xcode project's "Generate Localizable.strings" Run Script phase (see project.yml)
could call the exact same logic — including the hard-fail-on-key-mismatch check
between en.json/th.json, which is intentional (see CLAUDE.md).

Run standalone from the repo root (relative "assets/..." paths assume that cwd):
    python3 scripts/generate_localizable_strings.py
"""
import json
import os
import sys

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

if __name__ == "__main__":
    sys.exit(generate_localizable_strings())
