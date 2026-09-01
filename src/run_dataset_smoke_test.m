%% ELEC5305 real-data keyword-spotting smoke test
% A reproducible, toolbox-light baseline using Speech Commands v0.02.
% It follows TI's documented 49 x 10 MFCC front-end and uses a manual 5-NN
% classifier. This is a preliminary baseline, not a trained DSCNN/NPU result.

clear; close all; clc;
rng(5305, "twister");

cfg.fs = 16000;
cfg.clipSamples = 16000;
cfg.frameMs = 30;
cfg.hopMs = 20;
cfg.numMel = 40;
cfg.numMfcc = 10;
cfg.nfft = 512;
cfg.trainPerClass = 60;
cfg.testPerClass = 20;
cfg.knnK = 5;
cfg.labels = ["down","go","left","no","off","on", ...
    "right","stop","up","yes","_unknown_","_silence_"];
cfg.knownLabels = cfg.labels(1:10);

scriptPath = string(mfilename("fullpath"));
projectRoot = fileparts(fileparts(scriptPath));
overrideRoot = string(getenv("ELEC5305_SPEECH_COMMANDS_ROOT"));
localPathFile = fullfile(projectRoot,"data","local_dataset_path.txt");
if strlength(overrideRoot) > 0
    cfg.datasetRoot = overrideRoot;
elseif isfile(localPathFile)
    cfg.datasetRoot = strtrim(string(fileread(localPathFile)));
else
    cfg.datasetRoot = fullfile(projectRoot,"data","speech_commands_v0.02");
end
resultsDir = fullfile(projectRoot,"results");
assetsDir = fullfile(projectRoot,"docs","assets");
if ~isfolder(resultsDir), mkdir(resultsDir); end
if ~isfolder(assetsDir), mkdir(assetsDir); end

fprintf("ELEC5305_KEYWORD_SPOTTING_SMOKE_TEST\n");
fprintf("MATLAB=%s\n",version);
fprintf("DATASET_ROOT=%s\n",cfg.datasetRoot);
assert(isfolder(cfg.datasetRoot),"Dataset folder not found: %s",cfg.datasetRoot);

[manifest, splitAudit] = build_manifest(cfg);
publicManifest=manifest;
publicManifest.File=replace(erase(publicManifest.File,cfg.datasetRoot+filesep),filesep,"/");
publicManifest.Properties.VariableNames{'File'}='DatasetRelativeFile';
writetable(publicManifest,fullfile(resultsDir,"sample_manifest.csv"));
writetable(splitAudit,fullfile(resultsDir,"split_audit.csv"));

n = height(manifest);
featureDim = cfg.numMfcc*(2+7); % mean, std, and seven temporal block means
X = zeros(n,featureDim);
y = zeros(n,1);
mfccExample = [];
audioExample = [];
exampleLabel = "";
tic;
for i=1:n
    x = load_manifest_audio(manifest(i,:),cfg);
    M = ti_mfcc(x,cfg);
    X(i,:) = summarize_mfcc(M);
    y(i) = find(cfg.labels == string(manifest.Label(i)));
    if isempty(mfccExample) && manifest.Split(i)=="test" && manifest.Label(i)=="yes"
        mfccExample=M; audioExample=x; exampleLabel=string(manifest.Label(i));
    end
end
featureSeconds=toc;

isTrain = manifest.Split=="train";
isTest = manifest.Split=="test";
Xtrain=X(isTrain,:); ytrain=y(isTrain);
Xtest=X(isTest,:); ytest=y(isTest);

mu=mean(Xtrain,1); sigma=std(Xtrain,0,1); sigma(sigma<1e-8)=1;
Ztrain=(Xtrain-mu)./sigma; Ztest=(Xtest-mu)./sigma;

% Manual squared Euclidean distances and majority-vote k-NN.
D=sum(Ztest.^2,2)+sum(Ztrain.^2,2).'-2*(Ztest*Ztrain.');
[~,neighborIdx]=mink(D,cfg.knnK,2);
pred=mode(reshape(ytrain(neighborIdx),size(neighborIdx)),2);

nClass=numel(cfg.labels);
conf=accumarray([ytest pred],1,[nClass nClass]);
recall=diag(conf)./max(sum(conf,2),1);
precision=diag(conf)./max(sum(conf,1).',1);
accuracy=mean(pred==ytest);
macroRecall=mean(recall);

metrics=table(cfg.labels.',sum(conf,2),diag(conf),precision,recall, ...
    'VariableNames',{'Label','TestCount','Correct','Precision','Recall'});
writetable(metrics,fullfile(resultsDir,"per_class_metrics.csv"));
writematrix(conf,fullfile(resultsDir,"confusion_matrix.csv"));
save(fullfile(resultsDir,"baseline_model.mat"),"cfg","mu","sigma","Xtrain","ytrain");

f1=figure("Color","w","Position",[100 100 980 780]);
imagesc(conf); axis image; colorbar;
xticks(1:nClass); yticks(1:nClass); xticklabels(cfg.labels); yticklabels(cfg.labels);
xtickangle(45); xlabel("Predicted label"); ylabel("True label");
title(sprintf("Real Speech Commands smoke test: 5-NN accuracy %.1f%%",100*accuracy));
exportgraphics(f1,fullfile(resultsDir,"confusion_matrix.png"),"Resolution",170);
exportgraphics(f1,fullfile(assetsDir,"confusion_matrix.png"),"Resolution",170);

[S,F,T]=local_spectrogram(audioExample,cfg);
f2=figure("Color","w","Position",[100 100 1050 760]);
t=(0:numel(audioExample)-1)/cfg.fs;
subplot(3,1,1); plot(t,audioExample,"k"); grid on; xlim([0 1]);
xlabel("Time (s)"); ylabel("Amplitude"); title("Real held-out test utterance: "+exampleLabel);
subplot(3,1,2); imagesc(T,F,20*log10(abs(S)+1e-8)); axis xy; ylim([0 8000]);
colorbar; xlabel("Time (s)"); ylabel("Frequency (Hz)"); title("STFT magnitude (dB)");
subplot(3,1,3); imagesc((0:size(mfccExample,1)-1)*cfg.hopMs/1000,1:cfg.numMfcc,mfccExample.'); axis xy;
colorbar; xlabel("Frame time (s)"); ylabel("MFCC index"); title("TI-shaped MFCC feature map (49 x 10)");
exportgraphics(f2,fullfile(resultsDir,"real_audio_frontend.png"),"Resolution",170);
exportgraphics(f2,fullfile(assetsDir,"real_audio_frontend.png"),"Resolution",170);
writematrix(mfccExample,fullfile(resultsDir,"real_example_mfcc_49x10.csv"));

speakerLeakCount = sum(splitAudit.InTrain & splitAudit.InTest);
frontendPass = isequal(size(mfccExample),[49 10]) && all(isfinite(mfccExample),"all");
splitPass = speakerLeakCount==0;
baselinePass = accuracy > 1/nClass;
mvpPass = frontendPass && splitPass && baselinePass;

fid=fopen(fullfile(resultsDir,"SMOKE_TEST_RESULTS.txt"),"w");
fprintf(fid,"ELEC5305_KEYWORD_SPOTTING_SMOKE_TEST\n");
fprintf(fid,"dataset=Speech Commands v0.02\n");
fprintf(fid,"feature_shape=%dx%d\n",size(mfccExample,1),size(mfccExample,2));
fprintf(fid,"train_samples=%d\ntest_samples=%d\n",sum(isTrain),sum(isTest));
fprintf(fid,"knn_k=%d\naccuracy=%.6f\nmacro_recall=%.6f\n",cfg.knnK,accuracy,macroRecall);
fprintf(fid,"feature_seconds=%.3f\nspeaker_overlap_count=%d\n",featureSeconds,speakerLeakCount);
fprintf(fid,"FRONTEND_PASS=%d\nSPLIT_PASS=%d\nABOVE_CHANCE_PASS=%d\nSMOKE_TEST_PASS=%d\n", ...
    frontendPass,splitPass,baselinePass,mvpPass);
fclose(fid);

fprintf("train_samples=%d, test_samples=%d\n",sum(isTrain),sum(isTest));
fprintf("feature_shape=%dx%d\n",size(mfccExample,1),size(mfccExample,2));
fprintf("accuracy=%.2f%%, macro_recall=%.2f%%\n",100*accuracy,100*macroRecall);
fprintf("speaker_overlap_count=%d\n",speakerLeakCount);
fprintf("FRONTEND_PASS=%d SPLIT_PASS=%d ABOVE_CHANCE_PASS=%d SMOKE_TEST_PASS=%d\n", ...
    frontendPass,splitPass,baselinePass,mvpPass);
fprintf("RESULTS_DIR=%s\n",resultsDir);
assert(mvpPass,"Smoke test did not satisfy its declared evidence gates.");

function [manifest,audit] = build_manifest(cfg)
root=cfg.datasetRoot;
testList=replace(strtrim(readlines(fullfile(root,"testing_list.txt"))),"\","/");
valList=replace(strtrim(readlines(fullfile(root,"validation_list.txt"))),"\","/");
testList=testList(strlength(testList)>0); valList=valList(strlength(valList)>0);
reserved=unique([testList;valList]);
rows=cell(0,6);

for label=cfg.knownLabels
    d=dir(fullfile(root,label,"*.wav")); names=string({d.name}).';
    rel=label+"/"+names;
    trainPool=setdiff(rel,reserved,"stable");
    testPool=intersect(rel,testList,"stable");
    trainSel=pick_random(trainPool,cfg.trainPerClass);
    testSel=pick_random(testPool,cfg.testPerClass);
    for p=trainSel.', rows(end+1,:)={"train",label,label,fullfile(root,replace(p,"/",filesep)),0,"file"}; end %#ok<AGROW>
    for p=testSel.', rows(end+1,:)={"test",label,label,fullfile(root,replace(p,"/",filesep)),0,"file"}; end %#ok<AGROW>
end

allDirs=dir(root); allLabels=string({allDirs([allDirs.isdir]).name});
unknownLabels=setdiff(allLabels,[".","..","_background_noise_",cfg.knownLabels]);
unknownTrain=strings(0,1); unknownTest=strings(0,1);
for label=unknownLabels
    d=dir(fullfile(root,label,"*.wav")); rel=label+"/"+string({d.name}).';
    unknownTrain=[unknownTrain;setdiff(rel,reserved,"stable")]; %#ok<AGROW>
    unknownTest=[unknownTest;intersect(rel,testList,"stable")]; %#ok<AGROW>
end
trainSel=pick_random(unknownTrain,cfg.trainPerClass);
testSel=pick_random(unknownTest,cfg.testPerClass);
for p=trainSel.', rows(end+1,:)={"train","_unknown_",extractBefore(p,"/"),fullfile(root,replace(p,"/",filesep)),0,"file"}; end %#ok<AGROW>
for p=testSel.', rows(end+1,:)={"test","_unknown_",extractBefore(p,"/"),fullfile(root,replace(p,"/",filesep)),0,"file"}; end %#ok<AGROW>

noiseFiles=dir(fullfile(root,"_background_noise_","*.wav"));
assert(numel(noiseFiles)>=2,"At least two background-noise recordings are required.");
for split=["train","test"]
    if split=="train", fileIdx=1:max(numel(noiseFiles)-2,1); count=cfg.trainPerClass;
    else, fileIdx=max(numel(noiseFiles)-1,1):numel(noiseFiles); count=cfg.testPerClass; end
    for j=1:count
        nf=noiseFiles(fileIdx(1+mod(j-1,numel(fileIdx))));
        info=audioinfo(fullfile(nf.folder,nf.name)); maxStart=max(info.TotalSamples-cfg.clipSamples,0);
        frac=mod(j*0.61803398875,1); offset=floor(frac*maxStart);
        rows(end+1,:)={split,"_silence_","_background_noise_",fullfile(nf.folder,nf.name),offset,"noise"}; %#ok<AGROW>
    end
end

manifest=cell2table(rows,'VariableNames',{'Split','Label','SourceLabel','File','OffsetSamples','Kind'});
manifest.Split=string(manifest.Split); manifest.Label=string(manifest.Label);
manifest.SourceLabel=string(manifest.SourceLabel); manifest.File=string(manifest.File); manifest.Kind=string(manifest.Kind);

% Speaker IDs precede _nohash_. Noise sources are tracked separately by filename.
speaker=strings(height(manifest),1);
for i=1:height(manifest)
    [~,name]=fileparts(manifest.File(i));
    if manifest.Kind(i)=="noise", speaker(i)="noise:"+name;
    else, speaker(i)=extractBefore(name,"_nohash_"); end
end
u=unique(speaker);
inTrain=false(numel(u),1); inTest=false(numel(u),1);
for i=1:numel(u)
    inTrain(i)=any(speaker==u(i) & manifest.Split=="train");
    inTest(i)=any(speaker==u(i) & manifest.Split=="test");
end
% Separate noise recordings are selected for train and test, so noise IDs also audit cleanly.
audit=table(u,inTrain,inTest,'VariableNames',{'SpeakerOrNoiseID','InTrain','InTest'});
end

function out=pick_random(pool,n)
pool=unique(pool,"stable"); assert(numel(pool)>=n,"Pool has %d samples; need %d.",numel(pool),n);
out=pool(randperm(numel(pool),n));
end

function x=load_manifest_audio(row,cfg)
if row.Kind=="noise"
    first=double(row.OffsetSamples)+1; last=first+cfg.clipSamples-1;
    [x,fs]=audioread(row.File,[first last]); x=0.10*x;
else
    [x,fs]=audioread(row.File);
end
if size(x,2)>1, x=mean(x,2); end
if fs~=cfg.fs, x=resample(x,cfg.fs,fs); end
if numel(x)<cfg.clipSamples, x(end+1:cfg.clipSamples,1)=0;
elseif numel(x)>cfg.clipSamples, x=x(1:cfg.clipSamples); end
x=double(x(:));
end

function f=summarize_mfcc(M)
edges=round(linspace(1,size(M,1)+1,8)); pooled=zeros(7,size(M,2));
for b=1:7, pooled(b,:)=mean(M(edges(b):edges(b+1)-1,:),1); end
f=[mean(M,1),std(M,0,1),pooled(:).'];
end

function M=ti_mfcc(x,cfg)
L=round(cfg.frameMs*cfg.fs/1000); H=round(cfg.hopMs*cfg.fs/1000);
nFrames=1+floor((numel(x)-L)/H); idx=(0:L-1)'+(0:nFrames-1)*H+1;
w=0.54-0.46*cos(2*pi*(0:L-1)'/(L-1)); frames=x(idx).*w;
P=abs(fft(frames,cfg.nfft,1)).^2/cfg.nfft; P=P(1:cfg.nfft/2+1,:);
fb=mel_filterbank(cfg.numMel,cfg.nfft,cfg.fs); logMel=log(max(fb*P,1e-10));
n=cfg.numMel; k=(0:cfg.numMfcc-1)'; q=0:n-1; C=cos(pi/n*(q+0.5).*k);
C(1,:)=C(1,:)*sqrt(1/n); C(2:end,:)=C(2:end,:)*sqrt(2/n);
M=(C*logMel).';
end

function fb=mel_filterbank(nMel,nfft,fs)
hz2mel=@(f)2595*log10(1+f/700); mel2hz=@(m)700*(10.^(m/2595)-1);
m=linspace(hz2mel(20),hz2mel(fs/2),nMel+2); b=floor((nfft+1)*mel2hz(m)/fs);
fb=zeros(nMel,nfft/2+1);
for i=1:nMel
    for k=b(i):b(i+1)-1, fb(i,k+1)=(k-b(i))/max(b(i+1)-b(i),1); end
    for k=b(i+1):b(i+2), fb(i,k+1)=(b(i+2)-k)/max(b(i+2)-b(i+1),1); end
end
end

function [S,F,T]=local_spectrogram(x,cfg)
L=round(cfg.frameMs*cfg.fs/1000); H=round(cfg.hopMs*cfg.fs/1000);
n=1+floor((numel(x)-L)/H); idx=(0:L-1)'+(0:n-1)*H+1;
w=0.54-0.46*cos(2*pi*(0:L-1)'/(L-1)); S=fft(x(idx).*w,cfg.nfft,1);
S=S(1:cfg.nfft/2+1,:); F=(0:cfg.nfft/2)'*cfg.fs/cfg.nfft;
T=((0:n-1)*H+(L-1)/2)/cfg.fs;
end
