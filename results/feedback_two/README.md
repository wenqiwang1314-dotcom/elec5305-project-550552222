# Feedback Two: saved MATLAB experiment, 9 October 2026

This directory records an executed PC experiment, not TI hardware performance.
The experiment compares an equivalent cached MFCC implementation against the
original frontend on all 960 public audio samples. Timing isolates constant
reuse with the same feature-only kernel on both paths. See `summary.json`,
`cached_parity.csv`, `edge_probes.csv`, `timing_rounds.csv` and `validation.txt`.

From the repository root in MATLAB R2026a:

```matlab
addpath(fullfile('research','ti_gsc_matlab_mvp'))
benchmark_cached_frontend
```

This reruns measurements and overwrites this experiment's output files. Timing
will vary; exact feature parity is the acceptance gate, not a required speedup.
Data integrity, padding and disk I/O are outside the timed interval. The
89,280-byte constant payload excludes temporary buffers and runtime overhead.

Rebuild the report with Python 3.12 and `reportlab`, `matplotlib` installed:

```text
python tools/build_feedback_two.py
python tools/verify_feedback_two.py
python tools/verify_dsp_release.py --write-manifest
python tools/verify_dsp_release.py
```

The report builder consumes measured results, not handwritten timings. The
verifiers check saved consistency and hashes; only running MATLAB establishes
fresh numerical/timing evidence. The PDF must also be visually reviewed.

## Submission check

The signed-in Canvas page for assignment 695737 was inspected on 9 October
2026. Project Feedback Two requests a brief description with a GitHub Project
Site link and progress/code/results to date. It accepts PDF, MLX or ZIP; a PDF
is sufficient. The observed deadline was 9 October 2026, 23:59 Sydney time.

- Prepared: three-page progress PDF, student/SID, clickable public site and
  repository links, completed work, experimental results, limitations,
  milestones, three peer-reviewed research papers plus supporting references,
  and AI-assistance disclosure.
- Prepared: `SUBMISSION_FEEDBACK_TWO.txt` for a brief description if needed.
- Preserved: original proposal and previous report files.
- Not performed: Canvas upload, acceptance of academic-integrity declarations,
  or clicking Submit Assignment. The student must review the report and course
  rules before final submission; this checklist is not a submission receipt.
