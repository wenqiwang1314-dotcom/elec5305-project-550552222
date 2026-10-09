function plan = prepare_frontend(cfg)
%PREPARE_FRONTEND Precompute only constants; no waveform or data statistics.
% One plan belongs to a particular numerical configuration. Keep double
% precision and the original matrix products to isolate implementation cost.
validateattributes(cfg.fs,{'double'},{'scalar','integer','positive'});
validateattributes(cfg.num_mel,{'double'},{'scalar','integer','positive'});
validateattributes(cfg.num_mfcc,{'double'},{'scalar','integer','positive'});
L=round(cfg.frame_ms*cfg.fs/1000);
H=round(cfg.hop_ms*cfg.fs/1000);
assert(L>1 && H>0 && cfg.nfft>=L && mod(cfg.nfft,2)==0);
assert(cfg.num_mfcc<=cfg.num_mel);
plan.cfg=cfg;
[~,plan.window]=tigsc.window_frames(zeros(L,1));
[plan.filterbank,~]=tigsc.mel_filterbank(cfg.num_mel,cfg.nfft,cfg.fs);
[~,plan.dctBasis]=tigsc.dct_mfcc(zeros(cfg.num_mel,1),cfg);
% Payload excludes MATLAB struct metadata, working arrays and FFT internals.
plan.constantPayloadBytes=8*(numel(plan.window)+numel(plan.filterbank)+numel(plan.dctBasis));
end
