# Tiny Keyword Spotting with MATLAB

ELEC5305 project exploring a resource-aware 12-class keyword-spotting pipeline
inspired by Texas Instruments' Google Speech Commands example for the
MSPM0G5187. The project uses real Speech Commands v0.02 audio, a documented
`49 x 10` MFCC front end, and reproducible speaker-disjoint evaluation.

**Student:** Lucas(Wenqi) Wang (SID 550552222)  
**Project site:** https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/

## Current status

- Real dataset found and audited: 105,829 one-second 16 kHz WAV files.
- Official validation/test lists are respected.
- MATLAB smoke test: hand-written MFCC plus 5-nearest-neighbour baseline.
- Preliminary result: 39.17% accuracy/macro recall on 240 held-out samples,
  with zero audited speaker overlap (12-class chance level: 8.33%).
- DSCNN training, compression, and MCU deployment remain future work.

## Run

```matlab
cd('F:\CodeX_Workspace\elec5305-keyword-spotting\src')
run_dataset_smoke_test
```

The script writes its exact sample manifest, split audit, metrics, figures, and
machine-readable PASS/FAIL markers into `results/`.

## Evidence boundary

The smoke test is a small classical baseline used to validate data loading,
partitioning, and feature extraction. Its accuracy must not be reported as a
DSCNN, quantized NPU, or embedded-device result.

## Project site

The proposal site is in `docs/` and is ready to be served with GitHub Pages.
