# Resource-Aware Keyword Spotting with MATLAB and MFCC Features

## Student Information

- Full name: `Lucas(Wenqi) Wang`
- Student ID: `550552222`
- GitHub username: `wenqiwang1314-dotcom`
- GitHub repository: `https://github.com/wenqiwang1314-dotcom/elec5305-project-550552222`
- GitHub Project Site: `https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/`

## Project Overview

This project investigates a compact keyword-spotting system that recognises ten
spoken commands - down, go, left, no, off, on, right, stop, up, and yes - plus
unknown speech and silence. Keyword spotting is the small-vocabulary front end
used by voice-controlled devices before a larger speech recogniser is activated.
It must be accurate enough to avoid false activations, but computationally small
enough to run continuously on resource-constrained hardware. The proposed
solution is a reproducible MATLAB pipeline covering audio preparation,
Mel-frequency cepstral coefficient (MFCC) extraction, baseline classification,
and later comparison with a depthwise-separable convolutional neural network
(DSCNN). The design is inspired by Texas Instruments' 12-class Google Speech
Commands example for the MSPM0G5187, while the present project remains a PC-side
simulation until separate embedded deployment has been implemented and tested.

## Background and Motivation

Always-on keyword spotting must balance recognition, memory, computation, and
energy. MFCCs compactly describe the short-term spectral envelope on a
perceptually motivated Mel scale. Prior work establishes MFCCs, compact CNNs,
depthwise-separable CNNs, compression, and robust front ends as complementary
design choices. This project therefore connects ELEC5305 concepts - framing,
windowing, Fourier analysis, filterbanks, cepstral features, and objective
evaluation - to a practical edge-audio application.

## Proposed Methodology

The experiments will use Speech Commands v0.02, a public dataset containing
105,829 one-second spoken-word recordings at 16 kHz. The supplied official
validation and testing lists will be respected so recordings from the same
speaker do not leak across partitions. Ten commands will be retained as known
classes. Other word folders will form the unknown class, and one-second regions
from the background-noise recordings will form the silence class.

MATLAB will first standardise each clip to one second at 16 kHz. The acoustic
front end will follow the TI example: 30 ms frames, 20 ms frame step, 40 Mel
filters, and 10 MFCC coefficients. This produces 49 time frames by 10
coefficients for each utterance. A transparent k-nearest-neighbour classifier
will provide a smoke-test baseline and verify the complete data path without
requiring a deep-learning toolbox. The next model will be a compact DSCNN that
operates directly on the 49 by 10 feature map. Controlled experiments will
compare the baseline and DSCNN using identical data partitions. A fixed-manifest
front-end ablation now also compares coefficient count, frame step,
pre-emphasis, cepstral mean normalization (CMN), and a literature-motivated
log-Mel comparator while recording feature-map size and 10 dB robustness.

Evaluation will report overall test accuracy, per-class precision and recall,
macro recall, and a confusion matrix. Special attention will be given to the
unknown and silence classes because they determine false activations in a
realistic always-on system. Runtime, parameter count, and estimated memory will
be recorded for resource awareness. Repeated training seeds will be used before
drawing model-ranking conclusions. Hardware compilation or energy measurements
will be reported only if they are later performed on the named target under a
separate, documented protocol.

## Expected Outcomes

Deliverables are runnable MATLAB code, an exact manifest, acoustic figures,
machine-readable metrics, a verified literature set, and a GitHub Pages site.
The final target is a multi-seed DSCNN comparison with explicit accuracy,
unknown rejection, robustness, computation, and memory costs.

## Timeline

| Weeks | Work package |
|---|---|
| 1-2 | Define the 12-class task, audit the dataset, and review literature. |
| 3-5 | Implement and verify audio loading, official splits, MFCC extraction, and the baseline. |
| 6-9 | Implement the DSCNN, establish repeated-seed training, and tune only on validation data. |
| 10-11 | Evaluate test performance, runtime, memory, robustness, and error patterns. |
| 12-13 | Finalise the report, reproducibility package, GitHub documentation, and demonstration. |

## References

1. P. Warden, "Speech Commands: A Dataset for Limited-Vocabulary Speech Recognition," arXiv:1804.03209, 2018.
2. Y. Zhang, N. Suda, L. Lai, and V. Chandra, "Hello Edge: Keyword Spotting on Microcontrollers," arXiv:1711.07128, 2017.
3. S. B. Davis and P. Mermelstein, "Comparison of Parametric Representations for Monosyllabic Word Recognition in Continuously Spoken Sentences," IEEE Transactions on Acoustics, Speech, and Signal Processing, vol. 28, no. 4, pp. 357-366, 1980, doi:10.1109/TASSP.1980.1163420.
4. T. N. Sainath and C. Parada, "Convolutional Neural Networks for Small-footprint Keyword Spotting," Proceedings of Interspeech, pp. 1478-1482, 2015, doi:10.21437/Interspeech.2015-147.
5. G. Tucker, M. Wu, M. Sun, S. Panchapagesan, G. Fu, and S. Vitaladevuni, "Model Compression Applied to Small-Footprint Keyword Spotting," Proceedings of Interspeech, pp. 1878-1882, 2016, doi:10.21437/Interspeech.2016-1393.
6. Texas Instruments, "Google Speech Command Recognition," Tiny ML Tensorlab 1.4.0 User Guide, 2026.
7. Y. Wang et al., "Trainable Frontend for Robust and Far-Field Keyword Spotting," ICASSP, 2017, doi:10.1109/ICASSP.2017.7953242.
8. P. M. Sorensen, B. Epp, and T. May, "A Depthwise Separable Convolutional Neural Network for Keyword Spotting on an Embedded System," EURASIP JASMP, 2020, doi:10.1186/s13636-020-00176-2.
9. D. Peter, W. Roth, and F. Pernkopf, "Resource-efficient DNNs for Keyword Spotting using Neural Architecture Search and Quantization," arXiv:2012.10138, 2020.
10. A. Osman et al., "TinyML Platforms Benchmarking," arXiv:2112.01319, 2021.
11. A. Almaini, J. Folz, and G. Ashour, "TinyML for Acoustic Anomaly Detection in IoT Sensor Networks," arXiv:2603.26135, 2026.

## Preliminary Evidence

The first smoke test used 720 training and 240 held-out test utterances with a
manual 5-nearest-neighbour classifier. It produced the required 49 by 10 MFCC
map, found zero speaker overlap, and reached 39.17% accuracy and macro recall,
above the 8.33% chance level. Silence recall was 100%, but unknown-word recall
was 0%. On the identical manifest and classifier, adding utterance CMN raised
clean accuracy to 47.08% at the same 490-element input; pre-emphasis reached
41.67%. Denser 98-frame inputs added little despite doubling or tripling the
feature size. At 10 dB, every clean-trained variant fell to 8.33-10.42%, exposing
noise mismatch as a more important next problem than increasing MFCC size.
These are single-subset PC-side diagnostics, not DSCNN or embedded results.
