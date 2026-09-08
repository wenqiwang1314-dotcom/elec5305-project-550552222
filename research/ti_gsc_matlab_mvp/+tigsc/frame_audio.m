function [frames, sampleIndex, time] = frame_audio(x, cfg)
%FRAME_AUDIO Extract complete overlapping frames; discard an incomplete tail.
% Rows are samples within a frame; columns are successive frames. MATLAB
% indices start at one, whereas the time axis starts at zero seconds.
% L=480, H=320, N=16000 -> 1+floor((N-L)/H)=49 frames. The final 160
% samples are unused. Zero-padding below belongs to FFT, not to framing.
validateattributes(x, {'double'}, {'column','real','finite','nonempty'});
L = round(cfg.frame_ms*cfg.fs/1000);
H = round(cfg.hop_ms*cfg.fs/1000);
assert(numel(x)>=L, 'Input must contain at least one complete frame.');
nFrames = 1 + floor((numel(x)-L)/H);
sampleIndex = (0:L-1)' + (0:nFrames-1)*H + 1;
frames = x(sampleIndex);
time = ((0:nFrames-1)*H+(L-1)/2)/cfg.fs;
end
