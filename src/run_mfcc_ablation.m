%% ELEC5305 MFCC front-end ablation on the fixed smoke-test manifest
% This experiment isolates the acoustic front end: every row uses the same
% 720/240 speaker-disjoint manifest and the same manual 5-NN classifier.
% It compares TI's documented 49 x 10 MFCC configuration with bounded
% alternatives and a literature-motivated MFSC comparator. It is a PC-side
% diagnostic, not a DSCNN, quantization, NPU, latency, or energy result.

clear; close all; clc;

base.fs = 16000;
base.clipSamples = 16000;
base.knnK = 5;
base.labels = ["down","go","left","no","off","on", ...
    "right","stop","up","yes","_unknown_","_silence_"];
base.noiseSnrDb = 10;

scriptPath = string(mfilename("fullpath"));
projectRoot = fileparts(fileparts(scriptPath));
resultsDir = fullfile(projectRoot,"results");
assetsDir = fullfile(projectRoot,"docs","assets");
manifestPath = fullfile(resultsDir,"sample_manifest.csv");
localPathFile = fullfile(projectRoot,"data","local_dataset_path.txt");
overrideRoot = string(getenv("ELEC5305_SPEECH_COMMANDS_ROOT"));
if strlength(overrideRoot) > 0
    datasetRoot = overrideRoot;
elseif isfile(localPathFile)
    datasetRoot = strtrim(string(fileread(localPathFile)));
else
    datasetRoot = fullfile(projectRoot,"data","speech_commands_v0.02");
end

assert(isfile(manifestPath),"Run run_dataset_smoke_test.m first to create the fixed manifest.");
assert(isfolder(datasetRoot),"Dataset folder not found: %s",datasetRoot);
if ~isfolder(resultsDir), mkdir(resultsDir); end
if ~isfolder(assetsDir), mkdir(assetsDir); end

manifest = readtable(manifestPath,"TextType","string");
n = height(manifest);
assert(n==960,"Expected the fixed 960-row smoke-test manifest; found %d rows.",n);
isTrain = manifest.Split=="train";
isTest = manifest.Split=="test";
assert(sum(isTrain)==720 && sum(isTest)==240,"Unexpected train/test counts.");

y = zeros(n,1);
audio = zeros(base.clipSamples,n,"single");
noisyAudio = zeros(base.clipSamples,n,"single");
fprintf("ELEC5305_MFCC_ABLATION\n");
fprintf("MATLAB=%s\n",version);
fprintf("DATASET_ROOT=%s\n",datasetRoot);
fprintf("Loading the fixed manifest and creating deterministic %.1f dB test noise...\n",base.noiseSnrDb);
for i=1:n
    x = load_manifest_audio(manifest(i,:),datasetRoot,base);
    audio(:,i) = single(x);
    rng(900000+i,"twister");
    z = randn(size(x));
    z = z-mean(z);
    zRms = sqrt(mean(z.^2));
    xRms = max(sqrt(mean(x.^2)),1e-6);
    z = z/max(zRms,1e-12)*xRms*10^(-base.noiseSnrDb/20);
    noisyAudio(:,i) = single(x+z);
    y(i) = find(base.labels==manifest.Label(i),1);
end

variants = table( ...
    ["TI_ref_30_20_40_10";"MFCC_30_20_40_13";"MFCC_30_10_40_10"; ...
     "MFCC_25_10_40_13";"MFCC_TI_preemphasis";"MFCC_TI_CMN";"MFSC_40_20_20"], ...
    [30;30;30;25;30;30;40], ...
    [20;20;10;10;20;20;20], ...
    [40;40;40;40;40;40;20], ...
    [10;13;10;13;10;10;20], ...
    [512;512;512;512;512;512;1024], ...
    ["mfcc";"mfcc";"mfcc";"mfcc";"mfcc";"mfcc";"mfsc"], ...
    [0;0;0;0;0.97;0;0], ...
    ["none";"none";"none";"none";"none";"cmn";"none"], ...
    ["TI reference";"MFCC ablation";"MFCC ablation";"MFCC ablation"; ...
     "MFCC ablation";"MFCC ablation";"literature comparator"], ...
    'VariableNames',{'Variant','FrameMs','HopMs','MelBins','Coefficients', ...
    'NFFT','FeatureKind','Preemphasis','Normalization','Role'});

nVariants = height(variants);
cleanAccuracy = zeros(nVariants,1);
noiseAccuracy = zeros(nVariants,1);
cleanMacroRecall = zeros(nVariants,1);
noiseMacroRecall = zeros(nVariants,1);
cleanUnknownRecall = zeros(nVariants,1);
noiseUnknownRecall = zeros(nVariants,1);
featureElements = zeros(nVariants,1);
frameCount = zeros(nVariants,1);
runtimeMs = zeros(nVariants,1);
perClassRows = cell(0,6);

for v=1:nVariants
    p = table2struct(variants(v,:));
    example = extract_frontend(double(audio(:,1)),p,base.fs);
    frameCount(v) = size(example,1);
    featureElements(v) = numel(example);
    summaryDim = size(example,2)*9;
    Xclean = zeros(n,summaryDim);
    Xnoise = zeros(n,summaryDim);
    fprintf("[%d/%d] %s: %dx%d feature map\n",v,nVariants,p.Variant,size(example,1),size(example,2));
    t = tic;
    for i=1:n
        Xclean(i,:) = summarize_frontend(extract_frontend(double(audio(:,i)),p,base.fs));
        Xnoise(i,:) = summarize_frontend(extract_frontend(double(noisyAudio(:,i)),p,base.fs));
    end
    runtimeMs(v) = 1000*toc(t)/(2*n);

    mu = mean(Xclean(isTrain,:),1);
    sigma = std(Xclean(isTrain,:),0,1);
    sigma(sigma<1e-8)=1;
    Ztrain = (Xclean(isTrain,:)-mu)./sigma;
    Zclean = (Xclean(isTest,:)-mu)./sigma;
    Znoise = (Xnoise(isTest,:)-mu)./sigma;
    yTrain = y(isTrain);
    yTest = y(isTest);
    predClean = knn_predict(Ztrain,yTrain,Zclean,base.knnK);
    predNoise = knn_predict(Ztrain,yTrain,Znoise,base.knnK);
    [cleanAccuracy(v),cleanMacroRecall(v),cleanRecall] = score_predictions(yTest,predClean,numel(base.labels));
    [noiseAccuracy(v),noiseMacroRecall(v),noiseRecall] = score_predictions(yTest,predNoise,numel(base.labels));
    unknownIdx = find(base.labels=="_unknown_");
    cleanUnknownRecall(v) = cleanRecall(unknownIdx);
    noiseUnknownRecall(v) = noiseRecall(unknownIdx);
    for c=1:numel(base.labels)
        perClassRows(end+1,:) = {p.Variant,base.labels(c),cleanRecall(c),noiseRecall(c),sum(yTest==c),p.Role}; %#ok<AGROW>
    end
end

results = variants;
results.Frames = frameCount;
results.FeatureElements = featureElements;
results.RelativeElements = featureElements/featureElements(1);
results.CleanAccuracy = cleanAccuracy;
results.Noise10dBAccuracy = noiseAccuracy;
results.CleanMacroRecall = cleanMacroRecall;
results.Noise10dBMacroRecall = noiseMacroRecall;
results.CleanUnknownRecall = cleanUnknownRecall;
results.Noise10dBUnknownRecall = noiseUnknownRecall;
results.FrontendRuntimeMsPerUtterance = runtimeMs;
writetable(results,fullfile(resultsDir,"mfcc_ablation_results.csv"));

perClass = cell2table(perClassRows,'VariableNames', ...
    {'Variant','Label','CleanRecall','Noise10dBRecall','TestCount','Role'});
writetable(perClass,fullfile(resultsDir,"mfcc_ablation_per_class.csv"));

names = replace(results.Variant,"_"," ");
f1=figure("Color","w","Position",[100 100 1180 680]);
tiledlayout(2,1,"TileSpacing","compact","Padding","compact");
nexttile;
b=bar([100*cleanAccuracy,100*noiseAccuracy],"grouped");
b(1).FaceColor=[0.10 0.42 0.67]; b(2).FaceColor=[0.16 0.67 0.58];
ylim([0 max(55,ceil(max(cleanAccuracy)*100/5)*5+5)]); grid on;
ylabel("Accuracy (%)");
xticks(1:nVariants); xticklabels(names); xtickangle(18);
lgd1=legend("Clean","Deterministic 10 dB AWGN","Location","northwest");
title("MFCC front-end ablation on an identical fixed 5-NN protocol");
nexttile;
bar(featureElements,"FaceColor",[0.95 0.57 0.18]); grid on;
ylabel("Feature elements / clip");
xticks(1:nVariants); xticklabels(names); xtickangle(18);
xlabel("Front-end configuration");
style_figure(f1,lgd1);
exportgraphics(f1,fullfile(resultsDir,"mfcc_ablation_accuracy.png"),"Resolution",180);
exportgraphics(f1,fullfile(assetsDir,"mfcc_ablation_accuracy.png"),"Resolution",180);

f2=figure("Color","w","Position",[100 100 960 650]);
scatter(featureElements,100*cleanAccuracy,110,[0.10 0.42 0.67],"filled"); hold on;
scatter(featureElements,100*noiseAccuracy,110,[0.16 0.67 0.58],"filled");
for v=1:nVariants
    text(featureElements(v)+8,100*cleanAccuracy(v)+0.5,string(v),"Color",[0.10 0.32 0.55]);
    text(featureElements(v)+8,100*noiseAccuracy(v)-0.8,string(v),"Color",[0.05 0.48 0.38]);
end
grid on; xlabel("Feature-map elements per 1 s clip"); ylabel("Accuracy (%)");
lgd2=legend("Clean","10 dB AWGN","Location","best");
title("Accuracy / front-end-size trade-off (numbers follow CSV row order)");
style_figure(f2,lgd2);
exportgraphics(f2,fullfile(resultsDir,"mfcc_ablation_tradeoff.png"),"Resolution",180);
exportgraphics(f2,fullfile(assetsDir,"mfcc_ablation_tradeoff.png"),"Resolution",180);

splitAudit = readtable(fullfile(resultsDir,"split_audit.csv"));
speakerOverlap = sum(splitAudit.InTrain & splitAudit.InTest);
referenceShapePass = frameCount(1)==49 && variants.Coefficients(1)==10;
referenceReproPass = abs(cleanAccuracy(1)-0.391666666666667)<1e-10;
finitePass = all(isfinite(results{:,{'CleanAccuracy','Noise10dBAccuracy', ...
    'CleanMacroRecall','Noise10dBMacroRecall','FrontendRuntimeMsPerUtterance'}}),'all');
ablationPass = referenceShapePass && referenceReproPass && finitePass && speakerOverlap==0;
[~,bestCleanIdx] = max(cleanAccuracy);
[~,bestNoiseIdx] = max(noiseAccuracy);

fid=fopen(fullfile(resultsDir,"MFCC_ABLATION_RESULTS.txt"),"w");
fprintf(fid,"ELEC5305_MFCC_ABLATION\n");
fprintf(fid,"manifest_rows=%d\ntrain_samples=%d\ntest_samples=%d\n",n,sum(isTrain),sum(isTest));
fprintf(fid,"classifier=manual_5NN\nnoise_condition=deterministic_AWGN_%.1fdB\n",base.noiseSnrDb);
fprintf(fid,"ti_reference_shape=%dx%d\n",frameCount(1),variants.Coefficients(1));
fprintf(fid,"ti_reference_clean_accuracy=%.6f\n",cleanAccuracy(1));
fprintf(fid,"ti_reference_noise10db_accuracy=%.6f\n",noiseAccuracy(1));
fprintf(fid,"best_clean_variant=%s\nbest_clean_accuracy=%.6f\n",results.Variant(bestCleanIdx),cleanAccuracy(bestCleanIdx));
fprintf(fid,"best_noise_variant=%s\nbest_noise10db_accuracy=%.6f\n",results.Variant(bestNoiseIdx),noiseAccuracy(bestNoiseIdx));
fprintf(fid,"speaker_overlap_count=%d\n",speakerOverlap);
fprintf(fid,"REFERENCE_SHAPE_PASS=%d\nREFERENCE_REPRO_PASS=%d\nFINITE_RESULTS_PASS=%d\nMFCC_ABLATION_PASS=%d\n", ...
    referenceShapePass,referenceReproPass,finitePass,ablationPass);
fclose(fid);

disp(results(:,{'Variant','Role','Frames','Coefficients','FeatureElements', ...
    'CleanAccuracy','Noise10dBAccuracy','CleanUnknownRecall','Noise10dBUnknownRecall', ...
    'FrontendRuntimeMsPerUtterance'}));
fprintf("BEST_CLEAN=%s %.2f%%\n",results.Variant(bestCleanIdx),100*cleanAccuracy(bestCleanIdx));
fprintf("BEST_NOISE_10DB=%s %.2f%%\n",results.Variant(bestNoiseIdx),100*noiseAccuracy(bestNoiseIdx));
fprintf("REFERENCE_SHAPE_PASS=%d REFERENCE_REPRO_PASS=%d FINITE_RESULTS_PASS=%d MFCC_ABLATION_PASS=%d\n", ...
    referenceShapePass,referenceReproPass,finitePass,ablationPass);
assert(ablationPass,"MFCC ablation did not satisfy its reproducibility gates.");

function x=load_manifest_audio(row,datasetRoot,base)
path=fullfile(datasetRoot,replace(row.DatasetRelativeFile,"/",filesep));
if row.Kind=="noise"
    first=double(row.OffsetSamples)+1; last=first+base.clipSamples-1;
    [x,fs]=audioread(path,[first last]); x=0.10*x;
else
    [x,fs]=audioread(path);
end
if size(x,2)>1, x=mean(x,2); end
if fs~=base.fs, x=resample(x,base.fs,fs); end
if numel(x)<base.clipSamples, x(end+1:base.clipSamples,1)=0;
elseif numel(x)>base.clipSamples, x=x(1:base.clipSamples); end
x=double(x(:));
end

function F=extract_frontend(x,p,fs)
if p.Preemphasis>0
    x=filter([1 -p.Preemphasis],1,x);
end
L=round(p.FrameMs*fs/1000); H=round(p.HopMs*fs/1000);
nFrames=1+floor((numel(x)-L)/H);
idx=(0:L-1)'+(0:nFrames-1)*H+1;
w=0.54-0.46*cos(2*pi*(0:L-1)'/(L-1));
frames=x(idx).*w;
P=abs(fft(frames,p.NFFT,1)).^2/p.NFFT;
P=P(1:p.NFFT/2+1,:);
fb=mel_filterbank(p.MelBins,p.NFFT,fs);
logMel=log(max(fb*P,1e-10));
if p.FeatureKind=="mfsc"
    F=logMel.';
else
    n=p.MelBins; k=(0:p.Coefficients-1)'; q=0:n-1;
    C=cos(pi/n*(q+0.5).*k);
    C(1,:)=C(1,:)*sqrt(1/n);
    C(2:end,:)=C(2:end,:)*sqrt(2/n);
    F=(C*logMel).';
end
if p.Normalization=="cmn"
    F=F-mean(F,1);
end
end

function f=summarize_frontend(F)
edges=round(linspace(1,size(F,1)+1,8));
pooled=zeros(7,size(F,2));
for b=1:7
    pooled(b,:)=mean(F(edges(b):edges(b+1)-1,:),1);
end
f=[mean(F,1),std(F,0,1),pooled(:).'];
end

function pred=knn_predict(Ztrain,ytrain,Ztest,k)
D=sum(Ztest.^2,2)+sum(Ztrain.^2,2).'-2*(Ztest*Ztrain.');
[~,neighborIdx]=mink(D,k,2);
pred=mode(reshape(ytrain(neighborIdx),size(neighborIdx)),2);
end

function [accuracy,macroRecall,recall]=score_predictions(y,pred,nClass)
conf=accumarray([y pred],1,[nClass nClass]);
recall=diag(conf)./max(sum(conf,2),1);
accuracy=mean(pred==y);
macroRecall=mean(recall);
end

function fb=mel_filterbank(nMel,nfft,fs)
hz2mel=@(f)2595*log10(1+f/700);
mel2hz=@(m)700*(10.^(m/2595)-1);
m=linspace(hz2mel(20),hz2mel(fs/2),nMel+2);
b=floor((nfft+1)*mel2hz(m)/fs);
fb=zeros(nMel,nfft/2+1);
for i=1:nMel
    for k=b(i):b(i+1)-1
        fb(i,k+1)=(k-b(i))/max(b(i+1)-b(i),1);
    end
    for k=b(i+1):b(i+2)
        fb(i,k+1)=(b(i+2)-k)/max(b(i+2)-b(i+1),1);
    end
end
end

function style_figure(fig,lgd)
dark=[0.08 0.13 0.20];
axesHandles=findall(fig,"Type","axes");
set(axesHandles,"Color","w","XColor",dark,"YColor",dark, ...
    "GridColor",[0.73 0.78 0.83],"GridAlpha",0.55);
for i=1:numel(axesHandles)
    axesHandles(i).Title.Color=dark;
    axesHandles(i).XLabel.Color=dark;
    axesHandles(i).YLabel.Color=dark;
end
textHandles=findall(fig,"Type","text");
for i=1:numel(textHandles)
    if isequal(textHandles(i).Color,[0.8 0.8 0.8]) || ...
            isequal(textHandles(i).Color,[1 1 1])
        textHandles(i).Color=dark;
    end
end
set(lgd,"Color","w","TextColor",dark,"EdgeColor",[0.65 0.70 0.75]);
fig.Color="w";
end
