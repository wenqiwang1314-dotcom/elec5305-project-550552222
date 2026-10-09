# Efficient Audio Preprocessing and TI NPU Model Research Plan

> **Active focus (9 October 2026):** pre-model digital signal processing and
> DSP/DSCNN co-design. Start with [RESEARCH_FOCUS.md](RESEARCH_FOCUS.md) for the
> ordered experiment programme and evidence boundaries, and the
> [reproducible workbench](research/ti_gsc_matlab_mvp/README.md) for the two
> primary paper figures, modular MATLAB implementation and PlotNeuralNet source.

**Student:** Lucas(Wenqi) Wang (SID 550552222)
**Task:** 12-class Speech Commands classification
**Target anchor:** Texas Instruments `DSCNN_NPU` on MSPM0G5187
**Current boundary:** MATLAB preprocessing and classical baseline verified; NPU compilation and hardware measurements remain future work

## 1. Research objective

The project studies the complete path from an original audio waveform to a
resource-constrained classifier. The main question is:

> Which preprocessing pipeline and NPU-compatible model architecture provide
> the best balance of clean accuracy, noise robustness, unknown-word rejection,
> feature cost, model cost, and streaming latency?

This is a joint optimization problem. A stronger frontend may simplify the
classifier but consume more CPU cycles and memory; a larger network may recover
information discarded by compact features but exceed the embedded budget.
Frontend and model results will therefore be reported together rather than
treating MFCC generation as a fixed, cost-free operation.

## 2. Reproducible data contract

The source is Speech Commands v0.02: 105,829 WAV files sampled at 16 kHz. Ten
commands are retained, all other words form `_unknown_`, and background-noise
windows form `_silence_`. Official validation and testing lists define the
speaker-disjoint partitions.

The GitHub repository includes a fixed development subset as twelve class ZIP
archives. Each class has 60 training and 20 testing examples, giving 720/240
and 960 WAV files in total. Speech files are byte-for-byte source copies;
silence examples are documented one-second noise windows scaled by 0.10. The
manifest records provenance, offsets, format, derivation status, and SHA-256.
The full 3.34 GB local corpus remains the source for later full-scale training.

## 3. Processing chain and experimental variables

`waveform -> integrity checks -> conditioning -> framing/window -> spectrum -> Mel compression -> normalization -> tensor quantization -> DSCNN -> posterior/rejection`

### Stage A: waveform integrity and conditioning

- Verify sample rate, channel count, duration, finite values, clipping, and DC.
- Compare no conditioning, DC removal, RMS normalization, peak normalization,
  controlled automatic gain control, and pre-emphasis coefficients 0, 0.4,
  0.7, and 0.97.
- Test fixed one-second padding/cropping against energy/VAD-aligned cropping.
- Add reproducible time shift, gain, impulse response, and realistic noise
  augmentation only to training data.

### Stage B: time-frequency representation

- Use the TI reference as `P0`: 16 kHz, 1000 ms, 30 ms frame, 20 ms hop,
  40 Mel bins, 10 MFCCs, producing `[N,1,49,10]`.
- Sweep frame/hop only within bounded sets: 25/10, 30/10, 30/20, and 40/20 ms.
- Compare 10, 13, and 20 coefficients while recording tensor elements.
- Compare log-Mel/MFSC, MFCC, MFCC plus cepstral mean normalization, and PCEN.
- Precompute the window, triangular Mel matrix, and DCT matrix. Record one-time
  setup separately from per-clip runtime and require the cached and uncached
  feature maps to agree within a declared tolerance.
- Use per-coefficient temporal mean/std as a compact diagnostic only. Retain the
  ordered 49 x 10 map for DSCNN training because aggregation discards temporal
  evolution.
- Gate static+delta+delta-delta input as a 3 x 49 x 10 comparator: it triples
  input elements and must justify that cost against learned temporal kernels.
- Record frontend wall time on PC now; later measure MCU cycles, working RAM,
  and energy separately from NPU inference.

### Stage C: integer tensor interface

- Freeze the feature layout as channel x time x coefficient.
- Estimate calibration ranges from training/validation data only.
- Compare global and coefficient-wise affine int8 scaling when supported.
- Report saturation rate, reconstruction error, and float/int8 classification
  delta before NPU compilation.
- Save golden waveform, float feature, quantized tensor, and expected class so
  MATLAB, exported model, and embedded C can be checked sample by sample.

## 4. NPU-compatible model architecture

The official TI anchor is a 64-filter DSCNN: `Conv10x4 / stride 2`, dropout,
four `(Depthwise3x3 + Pointwise1x1)` blocks, dropout, adaptive average pooling,
and a 12-class fully connected output. Depthwise convolution learns local
time-frequency patterns; pointwise convolution mixes channels at much lower
cost than a standard convolution.

The controlled architecture matrix will keep NPU-supported operators and vary:

| ID | Width | DS blocks | Kernel study | Purpose |
|---|---:|---:|---|---|
| A0 | 64 | 4 | TI reference | Reproduce vendor anchor |
| A1 | 32 | 4 | 3x3 | Reduce weights and activations |
| A2 | 32/64 staged | 3 | 5x3 vs 3x3 | Test longer temporal context |
| A3 | 16/32 staged | 2 | 3x3 | Minimum viable NPU model |

Stride and channel width affect activation memory as well as multiply-accumulate
count, so parameter count alone is not sufficient. Unsupported operators,
implicit transposes, or CPU fallbacks fail the NPU-compatibility gate rather
than being hidden in an end-to-end timing number.

## 5. Evaluation protocol

Frontend variants will first use the fixed 5-NN diagnostic to isolate signal
processing effects. Promising candidates then enter the same DSCNN matrix.

- **Data:** identical speaker-disjoint train/validation/test lists.
- **Seeds:** at least three completed training seeds before model ranking.
- **Conditions:** clean plus realistic background noise at 20, 10, and 0 dB;
  optional room impulse responses and gain variation.
- **Recognition:** accuracy, macro recall, per-class recall, confusion matrix,
  and calibration.
- **Open set:** unknown recall, false accepts per hour, false rejects, and
  threshold curves on continuous audio.
- **Frontend cost:** tensor elements/bytes, runtime, working memory, and energy.
- **Model cost:** parameters, MACs, peak activation RAM, compiled flash, NPU
  coverage, latency, and energy per inference.
- **Verifier:** saved manifests, SHA-256, configuration, logs, golden tensors,
  exported ONNX/model files, and explicit pass/fail markers.

Validation data selects preprocessing, model, and rejection threshold. The test
set is used only after selection. Results from different data, seeds, or
hardware are never compared as if they share one protocol.

## 6. Current evidence and immediate decision

The [Feedback Two progress report](docs/feedback-two.html) now measures an
equivalent cached frontend on all 960 published recordings: all feature maps
match exactly. Nine warmed-up, alternating-order rounds give median batch-average
times of 0.658 ms uncached and 0.504 ms cached (1.31x). This measures PC MATLAB
feature-only processing, not inference or hardware energy. Constants use 89,280
bytes in double precision before scratch storage. Sparse/compact constants are
the next implementation question. Both paths right-pad the 84 short source clips
to 16,000 samples outside the timing interval; raw archives remain unchanged.

The TI-reference MFCC plus 5-NN gives 39.17% clean accuracy on the fixed subset.
Adding utterance cepstral mean normalization reaches 47.08% with the same 490
feature elements, while pre-emphasis reaches 41.67%. Denser feature maps do not
justify their 2.0-2.6x size in this diagnostic. All clean-trained variants fall
to 8.33-10.42% at 10 dB, and unknown recall remains 0-5%.

The immediate DSCNN candidates are therefore `P0` TI MFCC, `P1` TI MFCC plus
CMN, `P2` TI MFCC plus pre-emphasis/CMN, and `P3` PCEN or 20-bin MFSC. Every
candidate must be retrained with noise augmentation; the current 5-NN ordering
is a screening result, not a final model ranking.

The 5-NN study used 90 summary features (mean, standard deviation and seven
temporal bins), not a DSCNN operating on all 490 map values. Its small test
subset was examined during exploratory development. Future neural-network
selection must therefore use the official validation partition; do not present
these historical comparisons as an unbiased final ranking. For the remaining
coursework window, prioritize P0 versus P1 with a matched small DSCNN before
expanding the full design matrix.

## 7. Completion gates

1. **Data gate:** 12 classes, licensed provenance, valid audio, zero speaker
   leakage, and reproducible manifests.
2. **Frontend gate:** MATLAB and exported frontend agree on golden tensors;
   feature shape and int8 saturation are recorded.
3. **Model gate:** three seeds, validation-only selection, complete clean/noise
   and unknown metrics.
4. **Compiler gate:** ONNX/model compiles without unsupported-operator fallback;
   NPU coverage and memory reports are preserved.
5. **Hardware gate:** target latency, RAM/flash, and energy are measured on the
   named device. Until then, all such numbers remain explicitly unclaimed.

## References

- Texas Instruments, [Google Speech Command Recognition](https://software-dl.ti.com/C2000/esd/mcu_ai/01_04_00/user_guide/examples/google_speech_command.html), Tiny ML Tensorlab 1.4.0.
- P. Warden, [Speech Commands](https://arxiv.org/abs/1804.03209), 2018.
- Y. Wang et al., [Trainable Frontend for Robust and Far-Field Keyword Spotting](https://doi.org/10.1109/ICASSP.2017.7953242), ICASSP 2017.
- P. M. Sorensen et al., [A Depthwise Separable CNN for Keyword Spotting on an Embedded System](https://doi.org/10.1186/s13636-020-00176-2), 2020.
- K. S. Rao and S. G. Koolagudi, *Robust Emotion Recognition using Spectral and Prosodic Features*, Appendix A, Springer, 2013, doi:10.1007/978-1-4614-6360-3.
- T. Giannakopoulos and A. Pikrakis, *Introduction to Audio Analysis: A MATLAB Approach*, Chapter 4, Elsevier, 2014, doi:10.1016/B978-0-08-099388-1.00004-2.
