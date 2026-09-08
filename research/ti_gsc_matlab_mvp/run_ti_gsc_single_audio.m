function s = run_ti_gsc_single_audio(audioPath, outDir, visible)
%RUN_TI_GSC_SINGLE_AUDIO Explain the original front end using one real WAV.
% Usage:
%   run_ti_gsc_single_audio
%   run_ti_gsc_single_audio('D:/audio/yes.wav')
%   s=run_ti_gsc_single_audio('D:/audio/yes.wav','D:/results','off');
%
% Every numerical module is followed by its own figure, PNG and editable
% FIG. stage_data.mat contains all arrays. The final diagram is exported as
% PNG, vector PDF, SVG and FIG. This function does not train a classifier or
% manufacture class probabilities for a real speech example.
%
% Strict input policy: accept only finite, mono, 16 kHz, 16000-sample audio.
% The old front end did not define resampling, downmixing, padding, cropping
% or amplitude normalization. Reject mismatches instead of silently changing
% its numerical contract. A complete bundled real 'yes' recording is used
% by default; its original dataset path and SHA-256 are documented nearby.
projectDir=fileparts(mfilename('fullpath'));
addpath(projectDir);
if nargin<1 || isempty(audioPath) || strlength(string(audioPath))==0
    audioPath=fullfile(projectDir,'examples','yes.wav');
end
if nargin<2 || isempty(outDir) || strlength(string(outDir))==0
    outDir=fullfile(projectDir,'output','real_yes_walkthrough');
end
if nargin<3, visible='on'; end
assert(isfile(audioPath),'Audio file does not exist: %s',audioPath);
[x,fs]=audioread(audioPath);
cfg=tigsc.config();
assert(fs==cfg.fs,'Expected 16000 Hz; automatic resampling is intentionally absent.');
assert(size(x,2)==1,'Expected mono audio; supply an explicitly prepared mono WAV.');
assert(numel(x)==cfg.fs*cfg.duration_s,'Expected exactly 16000 samples (one second).');
assert(all(isfinite(x)),'Audio contains non-finite samples.');
[~,name,ext]=fileparts(audioPath);
opts=struct('outDir',char(outDir),'visible',char(visible), ...
    'source',char(audioPath),'label',['Real recording: ' name ext ' | feature extraction only']);
fprintf('SINGLE_AUDIO_SOURCE=%s\n',audioPath);
[M,s]=tigsc.frontend(x,cfg,opts);
s=tigsc.export_trace(s,opts);
tigsc.paper_flowchart(s,opts);
assert(isequal(size(M),[49 10]) && all(isfinite(M),'all'));
fprintf('SINGLE_AUDIO_FRONTEND_PASS=1\nBINARY_ROUNDTRIP_PASS=1\nOUTPUT_DIR=%s\n',outDir);
end
