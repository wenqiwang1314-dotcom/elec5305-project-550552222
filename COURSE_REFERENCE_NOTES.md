# Course Reference Notes for the Acoustic Front End

**Project:** ELEC5305 efficient audio preprocessing and TI NPU keyword spotting
**Scope:** Design evidence from the two supplied Week 3 course references
**Boundary:** The source PDFs are course materials and are not copied into this public repository

## 1. Evidence-to-design map

| Source location | Supported principle | Project decision | What is not transferred |
|---|---|---|---|
| Rao and Koolagudi, Appendix A, pp. 109-110 | Speech is analysed in short, overlapping, windowed frames because it is only locally quasi-stationary. Pre-emphasis compensates high-frequency roll-off. | Keep TI 30/20 ms as the deployment anchor, but test bounded 25/10, 30/10, 30/20, and 40/20 ms settings. Sweep pre-emphasis rather than treating 0.97 as universal. | The reference's typical 20/10 ms example is not assumed optimal for this 12-class task. |
| Rao and Koolagudi, Appendix A, pp. 110-112 | DFT power is integrated by a perceptually warped triangular Mel bank, log-compressed, and decorrelated by DCT. Low-order coefficients retain most envelope information. | Keep the complete MATLAB path explicit and compare 10, 13, and 20 coefficients under the same data and classifier. | The traditional 8-13 range is a prior, not a result for TI hardware. |
| Rao and Koolagudi, Appendix A, p. 112 | Delta and delta-delta coefficients add local temporal dynamics. | Treat static+delta+delta-delta as a gated comparator. A three-channel stack would triple input elements from 490 to 1470 before the model, so it proceeds only if it beats learned temporal convolution at a justified cost. | Speaker/emotion-recognition gains are not assumed to transfer to keyword spotting. |
| Giannakopoulos and Pikrakis, Chapter 4, pp. 59-66 | Feature extraction is both representation and data-rate reduction. Short-term feature sequences may be summarized by mid-term statistics, but long-term averaging discards temporal evolution. | Add a compact mean/std MFCC diagnostic while preserving the 49 x 10 ordered map for DSCNN training. Report accuracy and input bytes together. | Speech/music and music-genre examples are not used as KWS accuracy evidence. |
| Giannakopoulos and Pikrakis, Chapter 4, pp. 78-90 | Spectral features operate on frame DFTs; MFCC uses an overlapping Mel bank followed by log power and DCT. Constant filter weights and the DCT matrix can be precomputed. | Separate one-time coefficient setup from per-utterance runtime. Cache the window, Mel matrix, and DCT matrix, then require numerical equivalence to the uncached reference. | MATLAB desktop timing is not MCU latency or energy. |

## 2. Resulting bounded experiments

1. **Pre-emphasis:** compare coefficients `0`, `0.4`, `0.7`, and `0.97` with all
   other settings fixed.
2. **Temporal sampling:** compare the existing four frame/hop pairs without
   changing data, labels, or classifier.
3. **Temporal representation:** compare the full 49 x 10 map, a 20-value
   per-coefficient mean/std control, and a gated 3 x 49 x 10 static/delta/delta-
   delta tensor.
4. **Implementation efficiency:** precompute the window, Mel filters, and DCT;
   record setup time, per-clip time, persistent coefficient bytes, scratch RAM,
   and maximum feature error against the reference implementation.
5. **Deployment decision:** carry forward only variants that improve repeated-
   seed DSCNN performance or preserve performance with a measurable resource
   reduction. Classical 5-NN results remain screening evidence.

## 3. References

1. K. S. Rao and S. G. Koolagudi, *Robust Emotion Recognition using Spectral
   and Prosodic Features*, Appendix A, pp. 109-112, Springer, 2013,
   doi:10.1007/978-1-4614-6360-3.
2. T. Giannakopoulos and A. Pikrakis, *Introduction to Audio Analysis: A MATLAB
   Approach*, Chapter 4, pp. 59-103, Elsevier, 2014,
   doi:10.1016/B978-0-08-099388-1.00004-2.
