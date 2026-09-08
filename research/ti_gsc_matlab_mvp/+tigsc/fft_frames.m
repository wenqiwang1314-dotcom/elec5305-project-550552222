function [S, F] = fft_frames(windowed, cfg)
%FFT_FRAMES Compute a 512-point FFT along each 480-sample frame.
% MATLAB appends 32 zeros per column. Keep DC through Nyquist (257 bins).
% S contains complex coefficients; abs(S) is only used for visualization.
assert(cfg.nfft>=size(windowed,1) && mod(cfg.nfft,2)==0);
fullSpectrum = fft(windowed, cfg.nfft, 1);
S = fullSpectrum(1:cfg.nfft/2+1,:);
F = (0:cfg.nfft/2)'*cfg.fs/cfg.nfft;
end
