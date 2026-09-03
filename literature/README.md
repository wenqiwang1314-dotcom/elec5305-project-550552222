# Verified Literature Set

This folder separates archived open/source-supplied PDFs from publisher records
that were reviewed but not redistributed. The collection was checked on
2026-09-03. All eight archived PDFs passed signature, readability, page-count,
uniqueness, and SHA-256 validation; the first page of every paper was also
rendered and visually inspected.

## Archived PDFs

| Year | File | Pages | Role in this project | Source |
|---:|---|---:|---|---|
| 2017 | `Wang_2017_PCEN_Trainable_Frontend.pdf` | 5 | Robust compression/normalization candidate | Google Research / IEEE ICASSP |
| 2017 | `Zhang_2017_Hello_Edge.pdf` | 14 | MCU KWS and DS-CNN resource anchor | arXiv:1711.07128 |
| 2018 | `Tang_2018_Deep_Residual_KWS.pdf` | 5 | GSC residual-network benchmark | arXiv:1710.10361; IEEE ICASSP |
| 2018 | `Warden_2018_Speech_Commands_Dataset.pdf` | 11 | Dataset definition and split context | arXiv:1804.03209 |
| 2020 | `Peter_2020_Resource_Efficient_KWS.pdf` | 7 | 10-vs-20 MFCC and NAS/quantization trade-off | arXiv:2012.10138 |
| 2020 | `Sorensen_2020_DSCNN_Embedded_KWS.pdf` | 14 | 49-frame MFSC, realistic noise, quantization, streaming | DTU publisher manuscript; doi:10.1186/s13636-020-00176-2 |
| 2021 | `Osman_2021_TinyML_Platforms_Benchmarking.pdf` | 11 | Separate preprocessing, inference, and memory reporting | User-supplied arXiv:2112.01319 |
| 2025/26 | `Almaini_2025_TinyML_Acoustic_Anomaly_Detection.pdf` | 5 | Resource-aware MFCC method on a different acoustic task | User-supplied arXiv:2603.26135 |

Hashes are in `pdfs/SHA256SUMS.txt`; detailed machine results are in
`verification_report.json`.

## Publisher records reviewed (metadata only)

These records are linked rather than copied because an authenticated or open
publisher download was not established in this run.

| Venue | Paper | Why it matters | Link |
|---|---|---|---|
| ScienceDirect / Neurocomputing (2026) | Garai et al., *Advances in Small-footprint Keyword Spotting for TinyML* | Current survey organizing feature optimization, architecture, compression, NAS, and deployment | https://doi.org/10.1016/j.neucom.2026.134028 |
| ScienceDirect / Computer Speech & Language (2022) | van der Westhuizen et al., *Feature Learning for Efficient ASR-free Keyword Spotting in Low-resource Languages* | Learned representations outperform MFCCs in a different low-resource retrieval protocol | https://doi.org/10.1016/j.csl.2021.101275 |
| IEEE MIPRO (2025) | Medur, Lubbers, and Mausa, *Optimizing Keyword Spotting Classifier Based on Tiny Machine Learning for Low-Power Embedded Devices* | GSC v0.02, MFCC/CNN comparisons, PTQ, and energy/model-size trade-offs | https://doi.org/10.1109/MIPRO65660.2025.11131906 |
| IEEE ICASSP (2022) | *Keyword Spotting System using Low-complexity Feature Extraction and Quantized LSTM* | Tests a lower-complexity alternative to MFCC for embedded KWS | https://ieeexplore.ieee.org/document/9665486/ |

## Evidence boundaries

- Results from different datasets, label sets, partitions, augmentations,
  classifiers, and hardware are not numerically compared as if they were one
  benchmark.
- The attached anomaly-detection paper is binary UrbanSound8K classification,
  not 12-class Speech Commands KWS.
- The attached platform paper compares different MCU/framework combinations;
  it motivates reporting discipline but does not establish a universally faster
  frontend or framework.
- Publisher metadata was used for literature synthesis only. No paywall,
  institutional login, CAPTCHA, or access control was bypassed.
