#!/usr/bin/env python3
"""Writes edition/intune/models.json from the model pins in the Rust source.

Every speech model Nexus Voice can run is pinned in
src/transcription/artifacts.rs (and the speech detector in models.rs) by
file name, size, and SHA-256. The Intune scripts install only files that
match these pins, and the app checks them again before first use. Run this
after an upstream sync that changes a pin:

    python3 edition/intune/make-manifest.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = [ROOT / "src/transcription/artifacts.rs", ROOT / "src/transcription/models.rs"]
BLOCK = re.compile(r"const (\w+)_ARTIFACT: GgufArtifact = GgufArtifact \{(.*?)\n\};", re.S)
FIELD = re.compile(r'(\w+): ("(?:[^"\\]|\\.)*"|[\d_]+)')

models = []
for source in SOURCES:
    for name, body in BLOCK.findall(source.read_text()):
        fields = {key: value for key, value in FIELD.findall(body)}
        if "filename" not in fields:
            continue
        text = lambda key: json.loads(fields[key])
        models.append({
            "id": name.lower().replace("_", "-"),
            "file": text("filename"),
            "bytes": int(fields["bytes"].replace("_", "")),
            "sha256": text("sha256"),
            "source": f"https://huggingface.co/{text('repository')}/resolve/{text('revision')}/{text('filename')}",
        })

out = ROOT / "edition/intune/models.json"
out.write_text(json.dumps({"models": models}, indent=2) + "\n")
print(f"{len(models)} models -> {out.relative_to(ROOT)}")
