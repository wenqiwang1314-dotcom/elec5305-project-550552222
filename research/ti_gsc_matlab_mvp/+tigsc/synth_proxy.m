function x = synth_proxy(classId, variant, cfg, isTest)
%SYNTH_PROXY Unchanged deterministic speech-like generator from the original MVP.
% This is a test signal generator, not a recording of spoken words.
% Keep call order and RNG seed unchanged for exact regression checks.
N = cfg.fs; t = (0:N-1)'/cfg.fs;
if classId == 12
    x = 0.0025*randn(N,1);
    return
end
if classId == 11
    f = 180 + 500*rand(1,3);
else
    f = [180+37*classId, 520+83*classId, 1250+119*classId];
end
jitter = 1 + 0.015*randn;
if isTest, jitter = jitter*(1+0.01*sin(variant)); end
env = sin(pi*min(max((t-0.08)/0.18,0),1)).^2;
env(t>0.82) = cos(pi/2*min((t(t>0.82)-0.82)/0.18,1)).^2;
env = env .* (0.72 + 0.28*sin(2*pi*(2.2+0.08*classId)*t).^2);
x = zeros(N,1);
for h=1:3
    chirpRate = (classId-6.5)*18*(h==2);
    phase = 2*pi*(f(h)*jitter*t + 0.5*chirpRate*t.^2) + 0.2*h*variant;
    x = x + (1/h)*sin(phase);
end
x = env.*x;
x = x + (0.010 + 0.006*isTest)*randn(N,1);
x = 0.8*x/max(max(abs(x)),1e-9);
end

