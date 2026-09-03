# MFCC Front-End Optimization Analysis

**Student:** Lucas(Wenqi) Wang (SID 550552222)  
**Execution:** MATLAB R2026a Update 4, Speech Commands v0.02, fixed 720/240 speaker-disjoint subset  
**Scope:** PC-side front-end diagnostic; no DSCNN training, quantization, NPU compilation, MCU timing, or energy measurement

## 1. Reference configuration from Texas Instruments

The TI Google Speech Command example uses a 16 kHz, 1000 ms waveform, 30 ms
frames, a 20 ms frame step, 40 Mel filters, and 10 MFCC coefficients. For a
16,000-sample clip, the number of complete frames is

`1 + floor((16000 - 0.030*16000)/(0.020*16000)) = 49`.

The resulting model input is therefore `[N, 1, 49, 10]`, or 490 scalar feature
values per clip before quantization. The MATLAB implementation follows the
signal path from first principles: framing, Hamming window, power spectrum,
triangular Mel filterbank, stabilized log compression, and orthonormal DCT.

## 2. Controlled question

The question is not whether a larger model can beat the smoke test. It is:

> Holding the exact audio manifest, labels, classifier, training size, and test
> size fixed, which bounded front-end changes improve recognition, and what
> feature-map cost do they introduce?

All variants use the same manual 5-NN classifier and training-set
standardization. Models are trained only on clean features. Robustness is
probed by adding deterministic Gaussian noise to the held-out waveforms at
10 dB SNR. The noise result is deliberately a mismatch test, not a claim about
an augmentation-trained system.

## 3. Measured results

| Variant | Shape | Elements | Relative size | Clean accuracy | 10 dB accuracy | Clean unknown recall |
|---|---:|---:|---:|---:|---:|---:|
| TI reference: 30/20 ms, 40 Mel, 10 MFCC | 49 x 10 | 490 | 1.00x | 39.17% | 8.33% | 0% |
| 30/20 ms, 40 Mel, 13 MFCC | 49 x 13 | 637 | 1.30x | 40.42% | 8.33% | 0% |
| 30/10 ms, 40 Mel, 10 MFCC | 98 x 10 | 980 | 2.00x | 40.83% | 8.33% | 0% |
| 25/10 ms, 40 Mel, 13 MFCC | 98 x 13 | 1274 | 2.60x | 39.17% | 8.33% | 0% |
| TI reference plus pre-emphasis 0.97 | 49 x 10 | 490 | 1.00x | 41.67% | 8.33% | 0% |
| TI reference plus utterance CMN | 49 x 10 | 490 | 1.00x | **47.08%** | 10.00% | 5% |
| 40/20 ms, 20-bin MFSC comparator | 49 x 20 | 980 | 2.00x | 28.75% | **10.42%** | 5% |

The script reproduces the original TI-reference clean accuracy exactly
(39.1667%), confirms the 49 x 10 shape, and rechecks zero speaker overlap.
`MFCC_ABLATION_PASS=1` means these reproducibility gates passed; it does not
mean any front end is deployment-ready.

## 4. Interpretation

Cepstral mean normalization (CMN) is the strongest candidate in this limited
experiment: it improves clean accuracy by 7.92 percentage points while keeping
the 490-element feature map. Pre-emphasis also gives a small 2.50-point gain at
the same feature size. In contrast, doubling temporal density to 98 frames adds
only 1.67 points, and the largest 1274-element MFCC map does not improve on the
TI reference. More input values are therefore not automatically more useful.

Every clean-trained configuration falls to 8.33--10.42% at 10 dB, essentially
the 12-class chance region. This is the most important result: adjusting frame
or coefficient counts cannot substitute for noise-aware training and a robust
compression/normalization strategy. Unknown-word recall also remains 0--5%, so
an explicit open-set threshold or better unknown-class modelling is still
required.

MATLAB desktop front-end times were approximately 0.53--0.82 ms per utterance
in this run. These numbers are useful only for comparing this script on this PC;
they are not MCU latency or energy measurements. Feature elements are likewise
a transparent storage/activation proxy, not a full RAM estimate.

## 5. What the literature changes

- TI supplies a concrete reproducible anchor: 49 x 10 MFCC feeding a compact
  DSCNN on the MSPM0G5187 NPU. It is a reference configuration, not proof that
  these MFCC parameters are universally optimal.
- Wang et al. replace static log compression with per-channel energy
  normalization (PCEN), a dynamic automatic-gain-control front end designed for
  noisy and far-field KWS. This motivates a controlled PCEN comparison after
  the MATLAB baseline.
- Sorensen, Epp, and May retain 49 frames but use a 20-bin log-Mel/MFSC input,
  realistic noise augmentation, quantization, and continuous-stream posterior
  handling. Their work motivates the MFSC comparator and, more importantly,
  noise-matched training and streaming evaluation.
- Peter, Roth, and Pernkopf report an architecture-dependent trade-off between
  10 and 20 MFCC inputs under neural architecture search. Their result supports
  treating coefficient count as a joint front-end/model variable, not as an
  isolated universal optimum.
- The supplied TinyML benchmarking paper demonstrates that preprocessing,
  inference, memory, and platform must be reported separately. The supplied
  acoustic-anomaly paper uses 13 MFCCs on a different binary task; it supports
  resource-aware methodology but cannot validate a KWS parameter choice.
- Recent ScienceDirect and IEEE work organizes the design space around feature
  optimization, compact architectures, compression, and deployment metrics.
  Learned features can beat MFCCs in a different low-resource retrieval setting,
  but that evidence does not transfer numerically to this 12-class protocol.

## 6. Next experiment, in priority order

1. Keep the TI 49 x 10 front end as the deployment anchor and add CMN as the
   first same-size candidate.
2. Train the same compact DSCNN with clean plus realistic background-noise
   augmentation at multiple SNRs; tune only on validation data.
3. Compare TI MFCC, TI MFCC plus CMN, 20-bin MFSC, and PCEN under identical
   seeds, partitions, augmentation, and parameter budgets.
4. Add calibrated rejection for unknown speech and evaluate continuous audio,
   false accepts per hour, and detection latency.
5. Only after PC-side multi-seed closure, compile the selected model and measure
   target RAM, flash, latency, and energy on the named MCU.

## 7. Reproduction artifacts

- MATLAB script: `src/run_mfcc_ablation.m`
- Aggregate results: `results/mfcc_ablation_results.csv`
- Per-class recall: `results/mfcc_ablation_per_class.csv`
- Pass/fail record: `results/MFCC_ABLATION_RESULTS.txt`
- Figures: `results/mfcc_ablation_accuracy.png` and
  `results/mfcc_ablation_tradeoff.png`
- Verified paper archive: `literature/pdfs/` with `SHA256SUMS.txt`

## References

1. Texas Instruments, "Google Speech Command Recognition," Tiny ML TensorLab User Guide, 2026.
2. Y. Wang et al., "Trainable Frontend for Robust and Far-Field Keyword Spotting," ICASSP, 2017, doi:10.1109/ICASSP.2017.7953242.
3. P. M. Sorensen, B. Epp, and T. May, "A Depthwise Separable Convolutional Neural Network for Keyword Spotting on an Embedded System," EURASIP JASMP, 2020, doi:10.1186/s13636-020-00176-2.
4. D. Peter, W. Roth, and F. Pernkopf, "Resource-efficient DNNs for Keyword Spotting using Neural Architecture Search and Quantization," 2020, arXiv:2012.10138.
5. A. Osman et al., "TinyML Platforms Benchmarking," 2021, arXiv:2112.01319.
6. A. Almaini, J. Folz, and G. Ashour, "TinyML for Acoustic Anomaly Detection in IoT Sensor Networks," ICECCME 2025 / arXiv:2603.26135, 2026.
7. S. Garai et al., "Advances in Small-footprint Keyword Spotting for TinyML," Neurocomputing, vol. 695, 134028, 2026, doi:10.1016/j.neucom.2026.134028.
8. E. van der Westhuizen et al., "Feature Learning for Efficient ASR-free Keyword Spotting in Low-resource Languages," Computer Speech & Language, vol. 71, 101275, 2022, doi:10.1016/j.csl.2021.101275.
9. P. Medur, M. Lubbers, and G. Mausa, "Optimizing Keyword Spotting Classifier Based on Tiny Machine Learning for Low-Power Embedded Devices," MIPRO, 2025, doi:10.1109/MIPRO65660.2025.11131906.
