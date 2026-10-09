function summary = benchmark_cached_frontend()
%BENCHMARK_CACHED_FRONTEND Reproduce Feedback Two without a private corpus.
% Uses the twelve checked-in ZIPs. Neither labels nor test outcomes are used
% to select parameters. This tests an equivalent implementation, not a model.
% Timing excludes ZIP extraction, disk I/O, hashing, plotting and validation.
% Compare feature-only paths with identical kernel and input validation:
% uncached = prepare_frontend + frontend_cached; cached = frontend_cached.
work=fileparts(mfilename('fullpath')); root=fileparts(fileparts(work));
addpath(work);
out=fullfile(root,'results','feedback_two'); if ~isfolder(out),mkdir(out);end
scratch=tempname; mkdir(scratch); cleanup=onCleanup(@()rmdir(scratch,'s'));
subset=fullfile(root,'data','github_subset');
manifest=readtable(fullfile(subset,'manifest.csv'),'TextType','string');
assert(height(manifest)==960);
archives=readtable(fullfile(subset,'class_summary.csv'),'TextType','string');
for j=1:height(archives)
    p=fullfile(subset,'archives',archives.Archive(j));
    assert(strcmp(hashfile(p),archives.ArchiveSHA256(j)),'Archive hash mismatch');
    unzip(p,scratch);
end
cfg=tigsc.config(); plan=tigsc.prepare_frontend(cfg);
audio=cell(height(manifest),1); maxerr=zeros(height(manifest),1);
exact=false(height(manifest),1); sourceSamples=zeros(height(manifest),1);
fprintf('Checking 960 published waveforms against the modular reference...\n');
for i=1:height(manifest)
    p=fullfile(scratch,manifest.ArchiveMember(i));
    assert(strcmp(hashfile(p),manifest.SHA256(i)),'WAV hash mismatch');
    [x,fs]=audioread(p); assert(fs==cfg.fs && size(x,2)==1);
    sourceSamples(i)=numel(x);
    assert(numel(x)==manifest.Samples(i));
    % Raw source copies may be shorter than one second. Apply the documented
    % fixed-clip adapter once, before either frontend and outside timing.
    x=x(1:min(numel(x),16000)); x(end+1:16000,1)=0;
    audio{i}=x;
    ref=tigsc.frontend(x,cfg); candidate=tigsc.frontend_cached(x,plan);
    maxerr(i)=max(abs(ref-candidate),[],'all');
    exact(i)=isequal(ref,candidate);
    assert(isequal(size(candidate),[49 10]) && all(isfinite(candidate),'all'));
end
assert(all(exact),'Corpus equivalence failed');
rng(5305,'twister');
probes={zeros(16000,1),[1;zeros(15999,1)], ...
    sin(2*pi*440*(0:15999)'/16000),randn(16000,1), ...
    1e-12*randn(16000,1)};
probeNames=["zero";"impulse";"sine440";"noise";"near_zero"];
probeError=zeros(5,1);
for i=1:5
    a=tigsc.frontend(probes{i},cfg); b=tigsc.frontend_cached(probes{i},plan);
    probeError(i)=max(abs(a-b),[],'all'); assert(isequal(a,b));
end
% Reject bad inputs; rebuilding a plan for 13 coefficients must work.
invalid={zeros(1,16000),nan(16000,1),zeros(100,1)}; rejected=0;
for i=1:numel(invalid)
    try, tigsc.frontend_cached(invalid{i},plan); catch, rejected=rejected+1; end
end
assert(rejected==3);
cfg13=cfg; cfg13.num_mfcc=13;
assert(isequal(tigsc.frontend(audio{1},cfg13), ...
    tigsc.frontend_cached(audio{1},tigsc.prepare_frontend(cfg13))));
% 120 evenly spread clips cover every class. Alternate method order for
% nine rounds, after warming both paths, and retain every batch measurement.
selection=round(linspace(1,960,120));
for i=1:20
    uncached(audio{selection(i)},cfg); tigsc.frontend_cached(audio{selection(i)},plan);
end
uncachedMs=zeros(9,1); cachedMs=zeros(9,1); checksum=zeros(9,2);
for r=1:9
    if mod(r,2)==1, order=[1 2]; else, order=[2 1]; end
    for method=order
        acc=0; t=tic;
        for i=selection
            if method==1, M=uncached(audio{i},cfg);
            else, M=tigsc.frontend_cached(audio{i},plan); end
            acc=acc+M(1,1);
        end
        elapsed=1000*toc(t)/numel(selection);
        if method==1,uncachedMs(r)=elapsed;else,cachedMs(r)=elapsed;end
        checksum(r,method)=acc;
    end
end
assert(isequal(checksum(:,1),checksum(:,2)));
setupMs=zeros(21,1);
for i=1:numel(setupMs),t=tic; p=tigsc.prepare_frontend(cfg);setupMs(i)=1000*toc(t);end %#ok<NASGU>
parity=manifest(:,{'Label','Split','ArchiveMember','SHA256'});
parity.SourceSamples=sourceSamples;parity.MaxAbsoluteError=maxerr;parity.ExactMatch=exact;
writetable(parity,fullfile(out,'cached_parity.csv'));
writetable(table(probeNames,probeError,'VariableNames',{'Probe','MaxAbsoluteError'}),fullfile(out,'edge_probes.csv'));
writetable(table((1:9)',uncachedMs,cachedMs,uncachedMs./cachedMs, ...
    'VariableNames',{'Round','UncachedMsPerClip','CachedMsPerClip','Speedup'}),fullfile(out,'timing_rounds.csv'));
summary.date='2026-10-09'; summary.matlab=version;
summary.platform=computer; summary.cpu=getenv('PROCESSOR_IDENTIFIER');
summary.threadsPolicy='MATLAB default; shared desktop, no thread pinning';
summary.manifestSHA256=hashfile(fullfile(subset,'manifest.csv'));
summary.audioCount=960; summary.trainCount=sum(manifest.Split=="train");
summary.testCount=sum(manifest.Split=="test"); summary.exactMatches=sum(exact);
summary.shortClipsPadded=sum(sourceSamples<16000);
summary.longClipsCropped=sum(sourceSamples>16000);
summary.minimumSourceSamples=min(sourceSamples);
summary.maxAbsoluteError=max(maxerr); summary.edgeProbeCount=5;
summary.invalidInputsRejected=rejected; summary.changedConfigParity=true;
summary.shape=[49 10]; summary.outputFloat32Bytes=49*10*4;
summary.constantPayloadBytes=plan.constantPayloadBytes;
summary.cachedMedianMs=median(cachedMs);summary.uncachedMedianMs=median(uncachedMs);
summary.speedupRatioOfMedians=median(uncachedMs)/median(cachedMs);
summary.medianSetupMs=median(setupMs);
summary.timingRounds=9;summary.clipsPerRound=120;summary.timingManifestRows=selection;
summary.scope='PC MATLAB feature-only benchmark; not MCU latency, peak RAM or NPU inference';
summary.pass=true;
fid=fopen(fullfile(out,'summary.json'),'w');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(summary,PrettyPrint=true));fclose(fid);
fid=fopen(fullfile(out,'validation.txt'),'w');assert(fid>=0);
fprintf(fid,'CACHED_FRONTEND_PASS=1\nREAL_AUDIO_EXACT_MATCHES=960\nEDGE_PROBES=5\nMAX_ABSOLUTE_ERROR=0\nINVALID_INPUT_REJECTIONS=3\nCHANGED_CONFIG_PARITY_PASS=1\nTIMING_CHECKSUM_PASS=1\n');fclose(fid);
disp(summary); fprintf('CACHED_FRONTEND_PASS=1\n');
end

function M=uncached(x,cfg)
% Same feature-only kernel, rebuilding the exact same constants each call.
M=tigsc.frontend_cached(x,tigsc.prepare_frontend(cfg));
end

function h=hashfile(p)
fid=fopen(p,'rb');assert(fid>=0);guard=onCleanup(@()fclose(fid));
b=fread(fid,Inf,'*uint8');d=java.security.MessageDigest.getInstance('SHA-256');
d.update(b);h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
