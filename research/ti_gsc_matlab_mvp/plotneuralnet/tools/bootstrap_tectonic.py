"""Restore the pinned portable Windows x64 LaTeX engine from its release.

The downloaded archive's SHA-256 was checked against the official GitHub
release asset digest. Extraction is restricted to the expected executable;
no shell command or global PATH/registry change is performed.
"""
import hashlib
import io
import urllib.request
import zipfile
from pathlib import Path

URL = "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.17.0/tectonic-0.17.0-x86_64-pc-windows-msvc.zip"
SHA256 = "f61ce51f0b0ade1015b7de7ef368541c5424e9756ecbd0d7af97d6d48030845f"

if __name__ == "__main__":
    data = urllib.request.urlopen(URL, timeout=120).read()
    assert hashlib.sha256(data).hexdigest() == SHA256, "Release archive hash mismatch."
    target = Path(__file__).resolve().parent / "tectonic"
    target.mkdir(exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        (target / "tectonic.exe").write_bytes(archive.read("tectonic.exe"))
    print(f"TECTONIC_READY={target / 'tectonic.exe'}")
