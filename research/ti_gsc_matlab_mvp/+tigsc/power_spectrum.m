function P = power_spectrum(S, cfg)
%POWER_SPECTRUM Preserve the original P=abs(FFT).^2/NFFT convention.
% Do not double interior bins and do not divide by sample rate or window
% energy. This is the MVP's spectral power convention, not a calibrated PSD.
P = abs(S).^2/cfg.nfft;
end
