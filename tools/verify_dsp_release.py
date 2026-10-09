"""Verify the public DSP research package without MATLAB or third-party Python.

Checks cover published local HTML links, audio integrity, MFCC tensor order,
legacy evidence, required vendored TeX resources, accidental local-path/secret
leaks and an explicit SHA-256 release manifest. Numerical re-execution is a
separate MATLAB check; this script never treats a saved PASS marker as a new run.
"""
import argparse
import csv
import hashlib
import json
import re
import struct
import wave
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "research/ti_gsc_matlab_mvp"
MANIFEST = WORK / "RELEASE_SHA256SUMS.txt"
TEXT = {".md", ".txt", ".csv", ".json", ".html", ".py", ".ps1", ".m", ".sty", ".tex"}


def release_files():
    files = []
    for base in (WORK, ROOT / "docs/assets/research", ROOT / "results/feedback_two"):
        for path in base.rglob("*"):
            relative = path.relative_to(base)
            if any(part in {"output", ".venv", "__pycache__", ".git", "tectonic"}
                   for part in relative.parts):
                continue
            if path.is_file() and path != MANIFEST:
                assert path.suffix.lower() not in {".exe", ".zip", ".log", ".pyc"}, path
                files.append(path)
    files.extend(ROOT / name for name in (
        ".gitattributes", "README.md", "RESEARCH_FOCUS.md", "PREPROCESSING_NPU_RESEARCH_PLAN.md",
        "docs/index.html", "docs/dsp-model-codesign.html", "docs/feedback-two.html",
        "docs/assets/feedback_two_timing.png", "docs/dataset.html", "data/README.md",
        "docs/downloads/ELEC5305_Feedback_Two_Lucas_Wenqi_Wang_550552222.pdf",
        "SUBMISSION_FEEDBACK_TWO.txt", "SUBMISSION_TEXT.md",
        "tools/build_feedback_two.py", "tools/verify_feedback_two.py",
        "tools/import_dsp_research.py", "tools/verify_dsp_release.py"))
    return sorted(files)


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        self.links.extend(value for key, value in attrs if key in {"href", "src"} and value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-manifest", action="store_true")
    args = parser.parse_args()
    for name in ("index.html", "dsp-model-codesign.html", "feedback-two.html", "dataset.html"):
        page = ROOT / "docs" / name
        links = Links()
        links.feed(page.read_text(encoding="utf-8"))
        for link in links.links:
            url = urlsplit(link)
            if not url.scheme and not url.netloc and url.path:
                target = (page.parent / unquote(url.path)).resolve()
                assert target.is_relative_to(ROOT) and target.is_file(), (page, link)
    audio = WORK / "examples/yes.wav"
    assert hashlib.sha256(audio.read_bytes()).hexdigest() == (
        "2e38228747f53aab91ed5fdd0d9be74f834cf43f136e59c4de33c428bcb98fba")
    with wave.open(str(audio)) as wav:
        assert (wav.getframerate(), wav.getnchannels(), wav.getnframes(), wav.getsampwidth()) == (16000, 1, 16000, 2)
    trace = WORK / "evidence/real_yes_walkthrough"
    matrix = list(csv.reader((trace / "M.csv").open(encoding="utf-8")))
    assert len(matrix) == 49 and all(len(row) == 10 for row in matrix)
    packed = b"".join(struct.pack("<f", float(value)) for row in matrix for value in row)
    assert packed == (trace / "mfcc_frame_major_f32le.bin").read_bytes()
    contract = json.loads((trace / "feature_contract.json").read_text(encoding="utf-8"))
    assert contract["audio_source"] == "examples/yes.wav"
    assert contract["binary_bytes"] == len(packed) == 1960
    assert hashlib.sha256((WORK / "reference/run_ti_gsc_mvp_original.m").read_bytes()).hexdigest() == (
        "fd0e7fe259780c87f35ebed9de93b7b500fbd57fb25d08282d1138df1afce41c")
    evidence = (WORK / "evidence/validation/validation_results.txt").read_text()
    for marker in ("LEGACY_NUMERICAL_PARITY_PASS=1", "FRONTEND_PROBES=53", "MAX_ABSOLUTE_ERROR=0",
                   "REAL_WAV_PARITY_PASS=1", "TI_SDK_PARITY=UNVERIFIED"):
        assert marker in evidence, marker
    assert (WORK / "plotneuralnet/vendor/PlotNeuralNet/layers/init.tex").is_file()
    patterns = (
        r"(?i)[A-Z]:[/\\](?:Users|CodeX_Workspace|OneDrive|xwechat_files)[/\\ ]",
        r"gh[pousr]_[A-Za-z0-9]{30,}", r"github_pat_[A-Za-z0-9_]{30,}",
        r"AKIA[0-9A-Z]{16}", r"-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----",
    )
    files = release_files()
    for path in files:
        if path.suffix.lower() in TEXT and path.name != Path(__file__).name:
            content = path.read_text(encoding="utf-8-sig")
            # The root README has historical local run commands already public;
            # the new workbench and pages must be portable and free of host paths.
            for pattern in patterns:
                if path == ROOT / "README.md" and pattern == patterns[0]:
                    continue
                assert not re.search(pattern, content), f"Sensitive pattern: {path.relative_to(ROOT)}"
    manifest = "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT).as_posix()}\n"
                       for path in files)
    if args.write_manifest:
        MANIFEST.write_text(manifest, encoding="utf-8", newline="\n")
    else:
        assert MANIFEST.read_text(encoding="utf-8") == manifest, "Release manifest differs."
    print(f"DSP_RELEASE_PASS=1\nFILES_HASHED={len(files)}\nLOCAL_LINKS_PASS=1\nAUDIO_HASH_PASS=1\nFLOAT32_ROUNDTRIP_PASS=1\nPUBLIC_PATH_SCAN_PASS=1")


if __name__ == "__main__":
    main()
