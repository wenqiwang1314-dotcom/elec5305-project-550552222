# Dataset

The complete Speech Commands v0.02 corpus remains outside Git because its
105,829 WAV files occupy about 3.34 GB. Set `ELEC5305_SPEECH_COMMANDS_ROOT`,
place the corpus at `data/speech_commands_v0.02`, or put its absolute local path
in the ignored file `data/local_dataset_path.txt` before running MATLAB.

For transparent reproduction, `github_subset/archives/` contains twelve small
class archives: down, go, left, no, off, on, right, stop, up, yes, unknown, and
silence. Each archive contains the fixed 60 training and 20 testing examples
used by the current baseline, for 960 WAV files in total. Known and unknown
speech files are byte-for-byte copies of source WAV files. Silence examples are
explicitly marked derivatives: one-second background-noise windows scaled by
0.10, matching the smoke-test loader.

`github_subset/manifest.csv` records each archive member, split, source path,
source label, offset, audio format, derivation status, and SHA-256. The archive
hashes are in `github_subset/SHA256SUMS.txt`. Rebuild and verify with:

```matlab
run_dataset_smoke_test
export_github_audio_subset
```

```powershell
python tools/verify_github_audio_subset.py
```

Training excludes every path named in the official `validation_list.txt` and
`testing_list.txt`; testing uses only paths in `testing_list.txt`.

Speech Commands v0.02 is licensed CC BY 4.0. The license copy and per-archive
attribution notice identify the original TensorFlow download and Warden paper.
