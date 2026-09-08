# Primary workbench: DSP front end and DSCNN co-design

本目录是项目的主要工作对象：研究进入深度学习模型之前的数字信号处理，
并逐步与模型结构和量化接口协同优化。协议见
[RESEARCH_FOCUS.md](../../RESEARCH_FOCUS.md)。代码保留详细英文注释。

## MATLAB: a figure after each module

From the repository root in MATLAB (validated with R2026a):

```matlab
cd(fullfile('research','ti_gsc_matlab_mvp'))
run_ti_gsc_single_audio
% Optional headless run:
run_ti_gsc_single_audio([], [], 'off');
% Compare with the frozen original implementation and saved outputs:
validate_refactor
```

The bundled `examples/yes.wav` is a real Speech Commands recording; its
[attribution and SHA-256](examples/README.md) and CC BY 4.0 license are included.
The label `yes` is supplied by the dataset, not predicted by a model.

Each numerical stage in `+tigsc/` is followed by a visualization: waveform,
overlapping frames, Hamming window, FFT, power, Mel filters/energies, log-Mel,
MFCC, temporal summary and tensor export. Temporal mean/std is only for the
historical centroid diagnostic; the full 49-by-10 MFCC is the model input.
Output includes editable FIG files, PNG plots, a paper-style PDF/SVG pipeline,
CSV arrays and a float32 binary. Runtime output is Git-ignored; reviewed figures
are published under [`docs/assets/research`](../../docs/assets/research).

`reference/baseline.mat` is the frozen synthetic reference, not model weights.
Do not overwrite it with output from the implementation under test. The original
script and independent MFCC implementation are retained. Published
[`evidence/validation`](evidence/validation) records 53 probes with zero error
and exact agreement for 11 original workflow variables. This establishes MATLAB
refactor parity; TI SDK numerical parity is unverified.

## PlotNeuralNet: editable SCI-style architecture

See [`plotneuralnet/README.md`](plotneuralnet/README.md) for setup and rebuilding.
Edit `model.json` for channels, kernel/stride/padding, depth and classes; edit
`style.json` for appearance. `draw_model.py` propagates dimensions and uses
vendored, unmodified PlotNeuralNet Python/TikZ primitives. The pinned version and
MIT license are included. Local compiler binaries and environments are excluded.

The baseline uses 64 channels, four independent depthwise/pointwise blocks,
BN/ReLU after each convolution, dropout, adaptive average pooling and 12 logits.
The figure represents architecture; it does not represent trained inference.

## Exact baseline contract

16 kHz mono, exactly 16,000 samples; 480-sample symmetric Hamming window;
320-sample hop; 49 complete frames; FFT length 512; 257 retained frequency bins;
`abs(FFT).^2/512`; 40 triangular Mel filters over 20–8,000 Hz;
`ln(max(E,1e-10))`; orthonormal DCT-II coefficients c0–c9. The final frame ends
at sample 15,840. No implicit pre-emphasis, resampling, downmixing, padding,
cropping or normalization occurs.

Published arrays and the sanitized machine-readable contract are in
[`evidence/real_yes_walkthrough`](evidence/real_yes_walkthrough).
The 1,960-byte binary stores 490 float32 little-endian values, frame-major with
coefficient varying fastest. This is a host-side interchange example, not a
verified TI NPU tensor ABI or quantized input.

## Refresh the published artifacts

From the repository root, the independent standalone study can be imported with
`python tools/import_dsp_research.py --source /path/to/ti_gsc_matlab_mvp`.
The allowlist excludes execution logs, local paths and runtimes.
For direct work here, regenerate the MATLAB/PlotNeuralNet outputs, copy reviewed
PNG/PDF/SVG files into `docs/assets/research/`, and refresh the evidence arrays
and contract (use `examples/yes.wav` as the public audio path).
Run `python tools/verify_dsp_release.py --write-manifest`, then run it without
that flag to verify. Review the diff before committing.
