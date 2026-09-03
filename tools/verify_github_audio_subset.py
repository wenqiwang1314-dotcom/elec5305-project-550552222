from __future__ import annotations

import csv
import hashlib
import io
import wave
import zipfile
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SUBSET = ROOT / "data" / "github_subset"
ARCHIVES = SUBSET / "archives"
MANIFEST = SUBSET / "manifest.csv"
SUMMARY = SUBSET / "class_summary.csv"
LOCAL_ROOT_FILE = ROOT / "data" / "local_dataset_path.txt"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    with MANIFEST.open(newline="", encoding="utf-8-sig") as stream:
        rows = list(csv.DictReader(stream))
    with SUMMARY.open(newline="", encoding="utf-8-sig") as stream:
        summary = list(csv.DictReader(stream))

    assert len(rows) == 960
    assert len(summary) == 12
    counts = Counter((row["Label"], row["Split"]) for row in rows)
    for item in summary:
        label = item["Label"]
        assert counts[label, "train"] == 60
        assert counts[label, "test"] == 20

    expected_zip_hashes: dict[str, str] = {}
    for line in (SUBSET / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines():
        digest, name = line.split(" *", maxsplit=1)
        expected_zip_hashes[name] = digest.lower()

    rows_by_archive: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        rows_by_archive.setdefault(row["Archive"], []).append(row)

    dataset_root = None
    if LOCAL_ROOT_FILE.is_file():
        candidate = Path(LOCAL_ROOT_FILE.read_text(encoding="utf-8-sig").strip())
        if candidate.is_dir():
            dataset_root = candidate

    source_copy_count = 0
    wav_count = 0
    for item in summary:
        archive_name = item["Archive"]
        archive_path = ARCHIVES / archive_name
        assert archive_path.is_file()
        assert sha256_file(archive_path) == item["ArchiveSHA256"].lower()
        assert sha256_file(archive_path) == expected_zip_hashes[archive_name]
        archive_rows = rows_by_archive[archive_name]
        expected_members = {row["ArchiveMember"] for row in archive_rows}
        expected_members.add(f'{item["Label"]}/ATTRIBUTION.txt')
        with zipfile.ZipFile(archive_path) as bundle:
            assert bundle.testzip() is None
            actual_members = {name for name in bundle.namelist() if not name.endswith("/")}
            assert actual_members == expected_members
            for row in archive_rows:
                payload = bundle.read(row["ArchiveMember"])
                assert sha256_bytes(payload) == row["SHA256"].lower()
                with wave.open(io.BytesIO(payload), "rb") as wav:
                    assert wav.getframerate() == int(row["SampleRate"]) == 16000
                    assert wav.getnchannels() == int(row["Channels"]) == 1
                    assert wav.getnframes() == int(row["Samples"])
                wav_count += 1
                if dataset_root is not None and row["IsSourceByteCopy"] == "1":
                    source_path = dataset_root / Path(row["SourceRelativeFile"])
                    assert source_path.is_file()
                    assert sha256_file(source_path) == row["SHA256"].lower()
                    source_copy_count += 1

    assert wav_count == 960
    assert (SUBSET / "LICENSE_CC_BY_4.0.txt").is_file()
    print(f"ARCHIVE_COUNT={len(summary)}")
    print(f"WAV_COUNT={wav_count}")
    print("ZIP_CRC_PASS=1")
    print("MANIFEST_HASH_PASS=1")
    print("AUDIO_FORMAT_PASS=1")
    if dataset_root is None:
        print("SOURCE_BYTE_EQUIVALENCE=SKIPPED_LOCAL_DATASET_UNAVAILABLE")
    else:
        print(f"SOURCE_BYTE_COPY_COUNT={source_copy_count}")
        print("SOURCE_BYTE_EQUIVALENCE_PASS=1")
    print("DATASET_ARCHIVE_VERIFY_PASS=1")


if __name__ == "__main__":
    main()
