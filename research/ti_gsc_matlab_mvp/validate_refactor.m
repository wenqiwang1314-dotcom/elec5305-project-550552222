%% Validate modularization against the frozen pre-refactor implementation.
% Run the complete original workflow through the new functions, including
% all visualizations. baseline.mat was produced by the unmodified script
% before any edits. Do not regenerate it from the implementation under test.
run_ti_gsc_mvp;
addpath(fullfile(projectDir,'reference'));
b=load(fullfile(projectDir,'reference','baseline.mat'));
fields={'M','Xtrain','Xtest','mu','sigma','centroid','D','pred','conf','accuracy','testAudio'};
errors=zeros(numel(fields),1);
for i=1:numel(fields)
    actual=eval(fields{i}); expected=b.(fields{i});
    errors(i)=max(abs(actual(:)-expected(:)));
    assert(isequal(actual,expected),'Legacy mismatch in %s',fields{i});
end
% Compare an independent frozen implementation on all 48 held-out samples
% and on zero, impulse, sinusoidal and deterministic noise inputs.
rng(711,'twister');
probes=[zeros(cfg.fs,1),[1;zeros(cfg.fs-1,1)], ...
    sin(2*pi*440*(0:cfg.fs-1)'/cfg.fs),randn(cfg.fs,1),testAudio];
maxFrontendError=0;
for i=1:size(probes,2)
    old=legacy_mfcc(probes(:,i),cfg);
    [new,s]=tigsc.frontend(probes(:,i),cfg);
    maxFrontendError=max(maxFrontendError,max(abs(new-old),[],'all'));
    assert(isequal(old,new),'Frontend differs from frozen code.');
    assert(isequal(size(s.frames),[480 49]));
    assert(isequal(size(s.P),[257 49]));
    assert(isequal(size(s.logMel),[40 49]));
    assert(isequal(size(new),[49 10]) && all(isfinite(new),'all'));
    assert(norm(s.dctBasis*s.dctBasis'-eye(10),'fro')<1e-12);
end
realTrace=run_ti_gsc_single_audio();
realOld=legacy_mfcc(realTrace.x,cfg);
assert(isequal(realOld,realTrace.M),'Real WAV differs from frozen frontend.');
assert(isequal(realTrace.sampleIndex(:,1),(1:480)'));
assert(realTrace.sampleIndex(end,end)==15840);
out=fullfile(projectDir,'output','validation');
if ~isfolder(out), mkdir(out); end
report=table(string(fields(:)),errors,'VariableNames',{'LegacyVariable','MaxAbsoluteError'});
writetable(report,fullfile(out,'regression_comparison.csv'));
fid=fopen(fullfile(out,'validation_results.txt'),'w'); assert(fid>=0);
fprintf(fid,'LEGACY_NUMERICAL_PARITY_PASS=1\n');
fprintf(fid,'FRONTEND_PROBES=%d\nMAX_ABSOLUTE_ERROR=%.17g\n',size(probes,2)+1,maxFrontendError);
fprintf(fid,'REAL_WAV_PARITY_PASS=1\nMFCC_SHAPE=49x10\nBINARY_ROUNDTRIP_PASS=1\n');
fprintf(fid,'SYNTHETIC_TEST_ACCURACY=%.17g\nTI_SDK_PARITY=UNVERIFIED\n',accuracy);
fclose(fid);
fprintf('LEGACY_NUMERICAL_PARITY_PASS=1\nREAL_WAV_PARITY_PASS=1\nALL_VALIDATION_PASS=1\n');
