%% TI Google Speech Commands acoustic-analysis MVP (MATLAB)
% Faithfully reproduces the documented 16 kHz / 1 s / 49 x 10 MFCC front-end.
% The back-end is deliberately a small nearest-centroid baseline trained on
% synthetic speech-like signals; it is not TI's trained DSCNN_NPU model.

clear; close all; clc;
rng(42, "twister");

cfg.fs = 16000;
cfg.duration_s = 1;
cfg.frame_ms = 30;
cfg.hop_ms = 20;
cfg.num_mel = 40;
cfg.num_mfcc = 10;
cfg.nfft = 512;
cfg.labels = ["down","go","left","no","off","on", ...
    "right","stop","up","yes","_unknown_","_silence_"];
cfg.train_per_class = 8;
cfg.test_per_class = 4;

thisFile = mfilename("fullpath");
projectDir = fileparts(thisFile);
outDir = fullfile(projectDir, "output");
if ~isfolder(outDir), mkdir(outDir); end

fprintf("TI GSC MATLAB MVP\n");
fprintf("MATLAB=%s\n", version);
fprintf("fs=%d Hz, duration=%.0f ms, frame=%g ms, hop=%g ms, mel=%d, mfcc=%d\n", ...
    cfg.fs, 1000*cfg.duration_s, cfg.frame_ms, cfg.hop_ms, cfg.num_mel, cfg.num_mfcc);

% Generate a deterministic, self-contained proxy corpus. Each known class has
% a different formant-like trajectory. Unknown is randomized; silence is noise.
nClass = numel(cfg.labels);
nTrain = cfg.train_per_class * nClass;
nTest = cfg.test_per_class * nClass;
% The full 49x10 map is the DSCNN-facing representation. For this deliberately
% small MVP classifier, summarize it over time to avoid learning phase/alignment.
Xtrain = zeros(nTrain, 2*cfg.num_mfcc);
ytrain = zeros(nTrain, 1);
Xtest = zeros(nTest, 2*cfg.num_mfcc);
ytest = zeros(nTest, 1);
testAudio = zeros(cfg.fs, nTest);

row = 0;
for c = 1:nClass
    for k = 1:cfg.train_per_class
        row = row + 1;
        x = synth_proxy(c, k, cfg, false);
        M = ti_mfcc(x, cfg);
        Xtrain(row,:) = [mean(M,1), std(M,0,1)];
        ytrain(row) = c;
    end
end

row = 0;
for c = 1:nClass
    for k = 1:cfg.test_per_class
        row = row + 1;
        x = synth_proxy(c, 100+k, cfg, true);
        M = ti_mfcc(x, cfg);
        Xtest(row,:) = [mean(M,1), std(M,0,1)];
        ytest(row) = c;
        testAudio(:,row) = x;
    end
end

% Nearest-centroid baseline. Standardization is learned from training only.
mu = mean(Xtrain, 1);
sigma = std(Xtrain, 0, 1);
sigma(sigma < 1e-8) = 1;
Ztrain = (Xtrain-mu)./sigma;
Ztest = (Xtest-mu)./sigma;
centroid = zeros(nClass, size(Ztrain,2));
for c = 1:nClass, centroid(c,:) = mean(Ztrain(ytrain==c,:), 1); end
D = zeros(nTest, nClass);
for c = 1:nClass, D(:,c) = mean((Ztest-centroid(c,:)).^2, 2); end
[~, pred] = min(D, [], 2);

conf = accumarray([ytest pred], 1, [nClass nClass]);
accuracy = mean(pred == ytest);
perClassRecall = diag(conf)./max(sum(conf,2),1);

% Analyze and plot one held-out example.
exampleIdx = find(ytest == 10, 1); % "yes"
x = testAudio(:,exampleIdx);
M = ti_mfcc(x, cfg);
[S,F,T] = local_spectrogram(x, cfg);

f1 = figure("Color","w","Position",[100 100 1100 760]);
t = (0:numel(x)-1)/cfg.fs;
subplot(3,1,1); plot(t,x,"k"); grid on; xlim([0 1]);
xlabel("Time (s)"); ylabel("Amplitude"); title("Held-out synthetic speech proxy: yes");
subplot(3,1,2); imagesc(T,F,20*log10(abs(S)+1e-8)); axis xy;
ylim([0 8000]); colorbar; xlabel("Time (s)"); ylabel("Frequency (Hz)"); title("STFT magnitude (dB)");
subplot(3,1,3); imagesc((0:48)*cfg.hop_ms/1000,1:cfg.num_mfcc,M.'); axis xy;
colorbar; xlabel("Frame time (s)"); ylabel("MFCC index"); title("TI-shaped MFCC feature map (49 x 10)");
exportgraphics(f1, fullfile(outDir,"acoustic_frontend.png"), "Resolution", 160);

f2 = figure("Color","w","Position",[120 120 900 760]);
imagesc(conf); axis image; colorbar;
xticks(1:nClass); yticks(1:nClass); xticklabels(cfg.labels); yticklabels(cfg.labels);
xtickangle(45); xlabel("Predicted"); ylabel("True");
title(sprintf("Synthetic proxy confusion matrix, accuracy %.1f%%",100*accuracy));
exportgraphics(f2, fullfile(outDir,"confusion_matrix.png"), "Resolution", 160);

writematrix(M, fullfile(outDir,"example_mfcc_49x10.csv"));
writematrix(conf, fullfile(outDir,"confusion_matrix.csv"));
save(fullfile(outDir,"mvp_model.mat"), "cfg", "mu", "sigma", "centroid");

fid = fopen(fullfile(outDir,"results.txt"), "w");
fprintf(fid,"TI_GSC_MATLAB_MVP\nfeature_shape=%dx%d\n",size(M,1),size(M,2));
fprintf(fid,"train_samples=%d\ntest_samples=%d\naccuracy=%.6f\n",nTrain,nTest,accuracy);
for c=1:nClass, fprintf(fid,"recall_%s=%.6f\n",cfg.labels(c),perClassRecall(c)); end
frontendPass = isequal(size(M),[49 10]) && all(isfinite(M),"all");
classificationPass = accuracy >= 0.80;
fprintf(fid,"FRONTEND_PASS=%d\nCLASSIFICATION_MVP_PASS=%d\nMVP_PASS=%d\n", ...
    frontendPass,classificationPass,frontendPass && classificationPass);
fclose(fid);

fprintf("feature_shape=%dx%d\n",size(M,1),size(M,2));
fprintf("synthetic_test_accuracy=%.2f%%\n",100*accuracy);
fprintf("FRONTEND_PASS=%d\nCLASSIFICATION_MVP_PASS=%d\nMVP_PASS=%d\n", ...
    frontendPass,classificationPass,frontendPass && classificationPass);
fprintf("OUTPUT_DIR=%s\n",outDir);
assert(frontendPass, "MFCC output must be finite 49 x 10.");
assert(classificationPass, "Synthetic baseline accuracy fell below 80%%.");

function x = synth_proxy(classId, variant, cfg, isTest)
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

function M = ti_mfcc(x,cfg)
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

function [S,F,T] = local_spectrogram(x,cfg)
L=round(cfg.frame_ms*cfg.fs/1000); H=round(cfg.hop_ms*cfg.fs/1000);
n=1+floor((numel(x)-L)/H); idx=(0:L-1)'+(0:n-1)*H+1;
w=0.54-0.46*cos(2*pi*(0:L-1)'/(L-1));
S=fft(x(idx).*w,cfg.nfft,1); S=S(1:cfg.nfft/2+1,:);
F=(0:cfg.nfft/2)'*cfg.fs/cfg.nfft; T=((0:n-1)*H+(L-1)/2)/cfg.fs;
end
