function M = frontend_cached(x, plan)
%FRONTEND_CACHED Feature-only path using explicitly prepared constants.
% No hidden persistent cache: a changed configuration requires a new plan.
% Preserve double arithmetic, framing, FFT, absolute floor, c0 and DCT order.
frames=tigsc.frame_audio(x,plan.cfg);
windowed=frames.*plan.window;
S=fft(windowed,plan.cfg.nfft,1);
P=abs(S(1:plan.cfg.nfft/2+1,:)).^2/plan.cfg.nfft;
E=plan.filterbank*P;
M=(plan.dctBasis*log(max(E,1e-10))).';
end
