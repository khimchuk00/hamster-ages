#!/usr/bin/env python3
"""Builds HamsterAges/Localizable.xcstrings from the translation tables in this folder.

  strings_core.py  — keys used via L10n.t / L10n.f in code (marked extractionState=manual)
  strings_ui.py    — SwiftUI literal keys (Text("…"), Button("…"), …) that Xcode extracts itself

Usage:  python3 Tools/l10n/build_catalog.py [--check path/to/extracted_keys.txt]
--check lists extracted keys that have no translation yet (one key per line in the file).
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LANGS = ["uk", "de", "es", "fr", "it", "pt-BR", "ja", "ko", "zh-Hans", "zh-Hant", "tr"]
sys.path.insert(0, HERE)

import strings_core  # noqa: E402
import strings_ui    # noqa: E402

SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f)")


def specs(s):
    return sorted(re.sub(r"\d+\$", "", m) for m in SPEC.findall(s))


def forms(v):
    return list(v.values()) if isinstance(v, dict) else [v]


def check_formats(key, values):
    want = specs(key)
    for lang, val in zip(LANGS, values):
      for v in forms(val):
        if specs(v) != want:
            raise SystemExit(f"format mismatch [{lang}] {key!r} -> {v!r}")
        # literal percent signs must stay escaped exactly like the key
        if key.count("%%") != v.count("%%"):
            raise SystemExit(f"%% mismatch [{lang}] {key!r} -> {v!r}")


def entry(values, manual):
    e = {}
    if manual:
        e["extractionState"] = "manual"
    e["localizations"] = {lang: unit(v) for lang, v in zip(LANGS, values)}
    return e


def unit(v):
    """A plain string, or a dict of CLDR plural forms {"one": …, "few": …, "many": …, "other": …}."""
    if isinstance(v, dict):
        return {"variations": {"plural": {
            k: {"stringUnit": {"state": "translated", "value": x}} for k, x in v.items()}}}
    return {"stringUnit": {"state": "translated", "value": v}}


def main():
    strings = {}
    for key, values in strings_core.S.items():
        check_formats(key, values)
        strings[key] = entry(values, manual=True)
    for key, values in strings_ui.S.items():
        if key in strings:
            continue  # same text used both ways — one entry serves both
        check_formats(key, values)
        strings[key] = entry(values, manual=False)
    for key in getattr(strings_ui, "VERBATIM", []):
        strings.setdefault(key, {"shouldTranslate": False})

    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    out = os.path.join(ROOT, "HamsterAges", "Localizable.xcstrings")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, separators=(",", " : "))
        f.write("\n")
    print(f"wrote {len(strings)} keys × {len(LANGS)} languages → {os.path.relpath(out, ROOT)}")

    if len(sys.argv) > 2 and sys.argv[1] == "--check":
        extracted = [l.rstrip("\n") for l in open(sys.argv[2], encoding="utf-8") if l.strip()]
        missing = [k for k in extracted if k not in strings]
        print(f"{len(missing)} extracted keys without translation:")
        for k in missing:
            print("  " + json.dumps(k, ensure_ascii=False))


if __name__ == "__main__":
    main()
