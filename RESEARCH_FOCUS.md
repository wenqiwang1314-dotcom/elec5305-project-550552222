# Primary focus: pre-model DSP and joint optimization with DSCNN

Updated 8 September 2026. This is the active research scope and entry point.
The [detailed protocol](PREPROCESSING_NPU_RESEARCH_PLAN.md) remains the design
reference; previous 5-NN studies are preliminary diagnostics.

**Research question:** Which signal conditioning, time-frequency representation
and quantization interface preserve useful speech information at the lowest
end-to-end cost when paired with an appropriately sized TI-compatible DSCNN?

## The two primary artifacts

1. [Real-audio DSP pipeline (vector PDF)](docs/assets/research/paper_pipeline.pdf):
   one real `yes` recording, intermediate effects and the exact 49-by-10 output.
2. [DSCNN architecture using PlotNeuralNet (vector PDF)](docs/assets/research/dscnn_plotneuralnet.pdf):
   the downstream model, tensor dimensions and four depthwise-separable blocks.

The [workbench](research/ti_gsc_matlab_mvp/README.md) preserves modular MATLAB
functions, English comments, example audio, numerical evidence, configurable
PlotNeuralNet code, pinned dependencies and reproduction commands.
Figures represent numerical processing or sourced architecture, not model
accuracy or hardware performance.

## First-principles formulation

Let `X = Q(phi_theta(x))` and `z = f_w(X)`. The front end determines which
information survives; quantization determines numeric resolution; the model
learns how to use that information. A cheaper front end may require a larger
model, while a richer feature map can increase model computation and memory.
Optimize the complete path rather than evaluating components independently.

For an unpadded waveform, `T = 1 + floor((N-L)/H)`. The reference gives
`T = 1 + floor((16000-480)/320) = 49`, with ten coefficients per frame.
The tensor is `[batch,1,49,10]`; 490 elements occupy 1,960 bytes as float32 or
nominally 490 bytes as int8 before alignment and runtime overhead.
Changing hop or coefficient count changes DSP work and downstream tensor shapes.

For multiplier-one depthwise convolution followed by pointwise convolution,
convolution-only MACs are `T_out*F_out*(C_in*K_t*K_f + C_in*C_out)`.
This excludes normalization, activation, pooling, memory traffic and scheduling;
analytical MACs are not measured latency or energy.

For sequential execution, report
`t_total = t_DSP + t_pack/quantize + t_model + t_post`.
Separate initialization from steady-state processing. For overlapping execution,
measure end-to-end latency and throughput directly. Hardware energy requires
integrating power over a declared pipeline interval, reporting idle-baseline
treatment and distinguishing MCU-only from board/system boundaries. Identify
acquisition time, frame availability and algorithmic delay for streaming studies.

## Frozen reference

| Stage | Exact baseline | Research controls |
|---|---|---|
| Input | Mono, 16 kHz, 1 s; no implicit conditioning | DC removal, level control, pre-emphasis |
| Framing | 30 ms / 20 ms hop; 49 complete frames | Window/hop and streaming context |
| Spectrum | Symmetric Hamming, 512 FFT; `abs(FFT)^2/512` | Precomputation, precision, FFT cost |
| Mel | 40 triangular bands, 20–8,000 Hz; no area normalization | Band count/range and implementation |
| Compression | Natural log with floor `1e-10` | Log-Mel or PCEN with defined state initialization |
| Cepstrum | Orthonormal DCT-II, c0–c9 | Coefficient count, CMN, no-DCT representation |
| Interface | `[N,1,49,10]`, host float32 export | Layout, calibration, int8 saturation/error |
| Backbone | 64 channels, Conv 10x4/s2, four DW3x3 + PW1x1 blocks | Width/depth and compatible stem geometry |

The MATLAB reference has exact legacy parity. TI SDK numerical equivalence and
the deployed quantization/layout contract require independent golden vectors.
The model source is pinned in the [configuration](research/ti_gsc_matlab_mvp/plotneuralnet/model.json).
There is no residual connection, concatenation or softmax in this backbone.

## Ordered experiment programme — planned, not completed

| Phase | Controlled question | Output / gate |
|---|---|---|
| 0. Reproducibility | Does modularization preserve the original arithmetic? | Frozen original, 53 probes, stage plots and checksums; completed for the MATLAB reference |
| 1. Equivalent implementation | Can cached windows/filterbanks/DCT and fewer allocations reduce cost? | Fixed features; zero error for exact changes, declared tolerance for precision changes; setup/steady-state timing |
| 2. Fixed-shape DSP | Which conditioning, normalization or compression improves the same 49x10 interface? | One factor at a time, fixed 64-channel backbone, independently retrained weights, matched training budget |
| 3. Co-design | Do different T/F dimensions allow a smaller or better model? | Paired front ends and width/depth/stem variants, valid shapes, compiler-supported operators, accuracy/cost Pareto table |
| 4. Quantization | Which scale/layout retains accuracy and compiler coverage? | Training-only calibration subset, float/int8 golden tensors, saturation statistics, accuracy and compile report |
| 5. Embedded validation | Which candidate reduces complete-pipeline cost? | Device timing, peak RAM, flash, declared energy boundary, robustness and streaming rejection; separate hardware execution work |

A representation without DCT is not MFCC. Changing features requires retraining
and recalibration; reusing incompatible MFCC-trained weights confounds the
comparison. Utterance CMN uses future frames: evaluate a causal normalizer
separately for streaming. Noise augmentation and learned normalization or
calibration statistics use training data only.

## Fair comparison and evidence

- Freeze manifests and official train/validation/test partitions. Distinguish
  the 960-example development subset from full-corpus results.
- Select configurations and thresholds on validation data; reserve the test set
  for final evaluation. Use at least three matched seeds and report mean/std.
- Match splits, augmentation draws, optimizer schedule and selection rules
  within comparisons. Retrain each front-end/model pair.
- Record clean and 20/10/0 dB noise accuracy, macro recall, confusion, unknown and
  silence handling, and feature dimensions. False accepts per hour require
  continuous negative audio and duration, not a clip confusion matrix.
- Report DSP latency/workspace, packing cost, parameters, MAC convention,
  activation RAM, compiled flash/RAM and operator coverage. Report measured
  end-to-end latency/energy only when supporting measurements exist.
- Archive code/config hashes, manifests, seeds, training/calibration settings,
  golden outputs, tool versions and measurement provenance per experiment.

## Available evidence and open work

Available: real-audio stage plots and MFCC arrays; legacy parity over 53 probes
and 11 workflow variables; parameterized PlotNeuralNet diagrams and shape tests.
Synthetic centroid accuracy is a regression diagnostic. The earlier
[real-data 5-NN ablation](MFCC_OPTIMIZATION_ANALYSIS.md) is a separate diagnostic.

DSCNN training, TI SDK numerical parity, quantized inference, compiler acceptance
and hardware timing/energy remain open work. This publication establishes none
of those results.
