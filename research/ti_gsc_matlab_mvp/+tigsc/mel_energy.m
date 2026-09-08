function [E, fb, edgesHz] = mel_energy(P, cfg)
%MEL_ENERGY Integrate spectral power with the 40 triangular filters.
% (40 x 257)*(257 x 49) gives 40 x 49 linear Mel energies. This is not
% yet log-Mel and is not MFCC; the natural log and DCT are separate modules.
[fb, edgesHz] = tigsc.mel_filterbank(cfg.num_mel,cfg.nfft,cfg.fs);
E = fb*P;
end
