# Dataset

This repository does not redistribute the audio corpus. Set the environment
variable `ELEC5305_SPEECH_COMMANDS_ROOT`, place the corpus at
`data/speech_commands_v0.02`, or put its absolute local path in the ignored file
`data/local_dataset_path.txt` before running MATLAB. Training excludes every
path named in `validation_list.txt` and `testing_list.txt`. Testing uses only
paths in `testing_list.txt`. The generated `results/sample_manifest.csv`
records the exact subset used by the smoke test.

Speech Commands v0.02 is licensed CC BY 4.0. See the dataset's own `LICENSE`
and `README.md` files for attribution and terms.
