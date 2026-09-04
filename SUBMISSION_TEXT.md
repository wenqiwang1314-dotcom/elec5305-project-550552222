# Canvas submission draft

This project investigates efficient raw-audio preprocessing and NPU-compatible
keyword spotting for ten spoken commands, unknown speech, and silence using
MATLAB and Speech Commands v0.02. The GitHub Project Site documents the MFCC,
MFSC, PCEN, quantization, and DSCNN design space; the course references are
mapped to bounded experiments in pre-emphasis, temporal representation, and
precomputed Mel/DCT constants. The reproducible baseline reached 39.17% on 240
held-out samples with zero audited speaker overlap, while cepstral mean
normalization reached 47.08% at the same input size. Noise robustness and
unknown-word rejection define the next research stage.

GitHub Project Site: `https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/`
