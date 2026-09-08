function M = legacy_mfcc(x,cfg)
L = round(cfg.frame_ms*cfg.fs/1000); H = round(cfg.hop_ms*cfg.fs/1000);
nFrames = 1 + floor((numel(x)-L)/H);
idx = (0:L-1)' + (0:nFrames-1)*H + 1;
w = 0.54 - 0.46*cos(2*pi*(0:L-1)'/(L-1));
frames = x(idx).*w;
P = abs(fft(frames,cfg.nfft,1)).^2/cfg.nfft;
P = P(1:cfg.nfft/2+1,:);
fb = mel_filterbank(cfg.num_mel,cfg.nfft,cfg.fs);
logMel = log(max(fb*P,1e-10));
n = cfg.num_mel; k = (0:cfg.num_mfcc-1)'; q = 0:n-1;
C = cos(pi/n*(q+0.5).*k);
C(1,:) = C(1,:)*sqrt(1/n); C(2:end,:) = C(2:end,:)*sqrt(2/n);
M = (C*logMel).';
end

function fb = mel_filterbank(nMel,nfft,fs)
hz2mel = @(f) 2595*log10(1+f/700);
mel2hz = @(m) 700*(10.^(m/2595)-1);
m = linspace(hz2mel(20),hz2mel(fs/2),nMel+2);
b = floor((nfft+1)*mel2hz(m)/fs);
fb = zeros(nMel,nfft/2+1);
for i=1:nMel
    for k=b(i):b(i+1)-1, fb(i,k+1)=(k-b(i))/max(b(i+1)-b(i),1); end
    for k=b(i+1):b(i+2), fb(i,k+1)=(b(i+2)-k)/max(b(i+2)-b(i+1),1); end
end
end

