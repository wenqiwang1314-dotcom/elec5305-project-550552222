function [fb, edgesHz] = mel_filterbank(nMel, nfft, fs)
%MEL_FILTERBANK Reproduce the original 20 Hz--Nyquist triangular bank.
% Use the HTK-style frequency mapping and FLOOR((NFFT+1)*f/fs) bin mapping.
% Triangles are sampled on integer FFT bins and have no area normalization.
% Repeated adjacent edge bins are handled exactly as in the legacy loops.
hz2mel = @(f) 2595*log10(1+f/700);
mel2hz = @(m) 700*(10.^(m/2595)-1);
m = linspace(hz2mel(20),hz2mel(fs/2),nMel+2);
edgesHz = mel2hz(m);
b = floor((nfft+1)*edgesHz/fs);
fb = zeros(nMel,nfft/2+1);
for i=1:nMel
    for k=b(i):b(i+1)-1
        fb(i,k+1)=(k-b(i))/max(b(i+1)-b(i),1);
    end
    for k=b(i+1):b(i+2)
        fb(i,k+1)=(b(i+2)-k)/max(b(i+2)-b(i+1),1);
    end
end
end
