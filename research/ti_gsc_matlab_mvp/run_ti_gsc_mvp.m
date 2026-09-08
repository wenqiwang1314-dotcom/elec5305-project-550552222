%% TI Google Speech Commands acoustic-analysis MVP (MATLAB)
% Preserves the original 16 kHz / 1 s / 49 x 10 MATLAB MFCC implementation.
% Numerical parity with a TI SDK remains a separate, unverified requirement.
% The back-end is deliberately a small nearest-centroid baseline trained on
% synthetic speech-like signals; it is not TI's trained DSCNN_NPU model.

clear; close all; clc;
rng(42, "twister");
addpath(fileparts(mfilename('fullpath')));

cfg = tigsc.config();

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
        x = tigsc.synth_proxy(c, k, cfg, false);
        M = tigsc.frontend(x, cfg);
        Xtrain(row,:) = tigsc.summarize_mfcc(M);
        ytrain(row) = c;
    end
end

row = 0;
for c = 1:nClass
    for k = 1:cfg.test_per_class
        row = row + 1;
        x = tigsc.synth_proxy(c, 100+k, cfg, true);
        M = tigsc.frontend(x, cfg);
        Xtest(row,:) = tigsc.summarize_mfcc(M);
        ytest(row) = c;
        testAudio(:,row) = x;
    end
end

% Nearest-centroid baseline. Standardization is learned from training only.
model = tigsc.train_centroid(Xtrain,ytrain,cfg);
mu=model.mu; sigma=model.sigma; centroid=model.centroid;
[pred,D,Ztest] = tigsc.predict_centroid(Xtest,model);
Ztrain=(Xtrain-mu)./sigma;

conf = accumarray([ytest pred], 1, [nClass nClass]);
accuracy = mean(pred == ytest);
perClassRecall = diag(conf)./max(sum(conf,2),1);

% Analyze and plot one held-out example.
exampleIdx = find(ytest == 10, 1); % "yes"
x = testAudio(:,exampleIdx);
[M,trace] = tigsc.frontend(x, cfg);
S=trace.S; F=trace.frequency; T=trace.time;

f1 = figure("Color","w","Theme","light","Position",[100 100 1100 760]);
t = (0:numel(x)-1)/cfg.fs;
subplot(3,1,1); plot(t,x,"k"); grid on; xlim([0 1]);
xlabel("Time (s)"); ylabel("Amplitude"); title("Held-out synthetic speech proxy: yes");
subplot(3,1,2); imagesc(T,F,20*log10(abs(S)+1e-8)); axis xy;
ylim([0 8000]); colorbar; xlabel("Time (s)"); ylabel("Frequency (Hz)"); title("STFT magnitude (dB)");
subplot(3,1,3); imagesc((0:48)*cfg.hop_ms/1000,1:cfg.num_mfcc,M.'); axis xy;
colorbar; xlabel("Frame time (s)"); ylabel("MFCC index"); title("TI-shaped MFCC feature map (49 x 10)");
exportgraphics(f1, fullfile(outDir,"acoustic_frontend.png"), "Resolution", 160);

f2 = figure("Color","w","Theme","light","Position",[120 120 900 760]);
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

%% Single-example walkthrough: same held-out synthetic audio, every stage shown.
% The original output filenames and numerical evaluation above are retained.
% For a real recorded word, run run_ti_gsc_single_audio separately. Its output
% does not imply validity of this synthetic-trained classifier on real speech.
opts=struct('outDir',fullfile(outDir,'synthetic_yes_walkthrough'), ...
    'visible','on','label','Held-out synthetic yes proxy | original centroid baseline', ...
    'source','Original deterministic synthetic test corpus, first yes example');
[~,trace]=tigsc.frontend(x,cfg,opts);
trace=tigsc.export_trace(trace,opts);
[trace.pred,trace.D,trace.Z]=tigsc.predict_centroid(trace.features,model);
tigsc.plot_stage('10_classifier',trace,opts);
save(fullfile(opts.outDir,'baseline_prediction.mat'),'trace','model');
tigsc.paper_flowchart(trace,opts);
