# Efficient Audio Preprocessing and TI NPU Keyword Spotting

ELEC5305 project studying how raw-audio conditioning, time-frequency feature
extraction, tensor quantization, and compact model architecture can be jointly
optimized for 12-class audio classification on a TI NPU. The reproducible anchor
is Texas Instruments' Google Speech Commands DSCNN example for MSPM0G5187.

**Student:** Lucas(Wenqi) Wang (SID 550552222)

**Project site:** https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/

**Final proposal PDF:** [ELEC5305 Project Proposal](output/pdf/ELEC5305_Project_Proposal_Lucas_Wenqi_Wang_550552222.pdf)

## Current status

- Real dataset found and audited: 105,829 one-second 16 kHz WAV files.
- Official validation/test lists are respected.
- MATLAB smoke test: hand-written MFCC plus 5-nearest-neighbour baseline.
- Preliminary result: 39.17% accuracy/macro recall on 240 held-out samples,
  with zero audited speaker overlap (12-class chance level: 8.33%).
- Controlled MFCC ablation: TI plus utterance CMN reached 47.08% clean accuracy
  at the same 490-element input; all clean-trained variants remained near
  chance at 10 dB, motivating noise-aware training.
- Eight source-supplied/open research PDFs are archived with page-count and
  SHA-256 verification; ScienceDirect and IEEE publisher records are indexed.
- Twelve downloadable class archives contain the fixed 960-waveform development
  subset with provenance, split, format, derivation status, and SHA-256 records.
- DSCNN training, compression, and MCU deployment remain future work.

## Run

```matlab
cd('F:\CodeX_Workspace\elec5305-keyword-spotting\src')
run_dataset_smoke_test
run_mfcc_ablation
export_github_audio_subset
```

The script writes its exact sample manifest, split audit, metrics, figures, and
machine-readable PASS/FAIL markers into `results/`.

The detailed analysis is in [MFCC_OPTIMIZATION_ANALYSIS.md](MFCC_OPTIMIZATION_ANALYSIS.md),
the supplied course references are mapped to testable design decisions in
[COURSE_REFERENCE_NOTES.md](COURSE_REFERENCE_NOTES.md),
the full research protocol is in
[PREPROCESSING_NPU_RESEARCH_PLAN.md](PREPROCESSING_NPU_RESEARCH_PLAN.md),
and the corresponding project page is
https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/mfcc-optimization.html.

Download the twelve class archives from the
[dataset page](https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/dataset.html).

## Evidence boundary

The smoke test and MFCC ablation are small classical diagnostics used to isolate
data loading, partitioning, and preprocessing. Their accuracy and desktop timing
must not be reported as DSCNN, quantized NPU, or embedded-device results.

## Project site

The proposal site is in `docs/` and is ready to be served with GitHub Pages.
