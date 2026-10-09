"""Audit saved Feedback Two evidence; this does not re-execute MATLAB."""
import csv
import hashlib
import json
import math
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULT = ROOT / "results/feedback_two"


def rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def main():
    s = json.loads((RESULT / "summary.json").read_text())
    manifest_path = ROOT / "data/github_subset/manifest.csv"
    assert s["manifestSHA256"] == hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    manifest, parity = rows(manifest_path), rows(RESULT / "cached_parity.csv")
    assert len(manifest) == len(parity) == s["audioCount"] == 960
    for source, measured in zip(manifest, parity):
        for key in ("Label", "Split", "ArchiveMember", "SHA256"):
            assert source[key] == measured[key], (key, source["ArchiveMember"])
        assert int(source["Samples"]) == int(measured["SourceSamples"])
        assert measured["ExactMatch"] == "1" and float(measured["MaxAbsoluteError"]) == 0
    assert s["exactMatches"] == 960 and s["maxAbsoluteError"] == 0
    assert s["trainCount"] == sum(r["Split"] == "train" for r in parity) == 720
    assert s["testCount"] == sum(r["Split"] == "test" for r in parity) == 240
    lengths = [int(r["Samples"]) for r in manifest]
    assert s["shortClipsPadded"] == sum(n < 16000 for n in lengths) == 84
    assert s["longClipsCropped"] == sum(n > 16000 for n in lengths) == 0
    assert s["minimumSourceSamples"] == min(lengths) == 7509
    edges = rows(RESULT / "edge_probes.csv")
    assert len(edges) == s["edgeProbeCount"] == 5
    assert all(float(r["MaxAbsoluteError"]) == 0 for r in edges)
    assert s["invalidInputsRejected"] == 3 and s["changedConfigParity"]
    rounds = rows(RESULT / "timing_rounds.csv")
    assert len(rounds) == s["timingRounds"] == 9
    assert [int(r["Round"]) for r in rounds] == list(range(1, 10))
    uncached = statistics.median(float(r["UncachedMsPerClip"]) for r in rounds)
    cached = statistics.median(float(r["CachedMsPerClip"]) for r in rounds)
    for row in rounds:
        a, b = float(row["UncachedMsPerClip"]), float(row["CachedMsPerClip"])
        assert a > 0 and b > 0 and math.isclose(a/b, float(row["Speedup"]), rel_tol=1e-12)
    for expected, actual in ((uncached, s["uncachedMedianMs"]), (cached, s["cachedMedianMs"]),
                             (uncached/cached, s["speedupRatioOfMedians"])):
        assert math.isclose(expected, actual, rel_tol=1e-12)
    assert len(set(s["timingManifestRows"])) == s["clipsPerRound"] == 120
    assert min(s["timingManifestRows"]) == 1 and max(s["timingManifestRows"]) == 960
    assert s["constantPayloadBytes"] == (480+40*257+10*40)*8 == 89280
    assert s["shape"] == [49, 10] and s["outputFloat32Bytes"] == 1960 and s["pass"]
    build = json.loads((RESULT / "report_build.json").read_text())
    assert 700 <= build["narrativeWords"] <= 1000
    name = "ELEC5305_Feedback_Two_Lucas_Wenqi_Wang_550552222.pdf"
    pdf = (ROOT / "output/pdf" / name).read_bytes()
    assert pdf.startswith(b"%PDF-") and pdf == (ROOT / "docs/downloads" / name).read_bytes()
    assert hashlib.sha256(pdf).hexdigest() == build["pdfSHA256"]
    assert hashlib.sha256((RESULT / "summary.json").read_bytes()).hexdigest() == build["summarySHA256"]
    print("FEEDBACK_TWO_EVIDENCE_PASS=1\nREAL_AUDIO_ROWS=960\nTIMING_ROUNDS=9\nREPORT_HASH_PASS=1")


if __name__ == "__main__":
    main()
