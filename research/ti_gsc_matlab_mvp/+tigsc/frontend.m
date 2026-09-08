function [M, s] = frontend(x, cfg, opts)
%FRONTEND Execute independently inspectable modules in the original order.
% Without opts, perform numerical work only (fast corpus extraction). With
% opts.outDir and opts.visible, display/export each result immediately after
% its module finishes. Plotting never modifies the numerical arrays.
if nargin<3, opts=struct(); end
show = isfield(opts,'outDir');
s.x = x; s.cfg = cfg;
if show, tigsc.plot_stage('00_audio',s,opts); end
[s.frames,s.sampleIndex,s.time] = tigsc.frame_audio(x,cfg);
[~,peakFrame] = max(sum(s.frames.^2,1));
start = max(1,min(peakFrame-1,size(s.frames,2)-2));
s.selected = start:min(start+2,size(s.frames,2));
if show, tigsc.plot_stage('01_framing',s,opts); end
[s.windowed,s.window] = tigsc.window_frames(s.frames);
if show, tigsc.plot_stage('02_window',s,opts); end
[s.S,s.frequency] = tigsc.fft_frames(s.windowed,cfg);
if show, tigsc.plot_stage('03_fft',s,opts); end
s.P = tigsc.power_spectrum(s.S,cfg);
if show, tigsc.plot_stage('04_power',s,opts); end
[s.melEnergy,s.filterbank,s.melEdgesHz] = tigsc.mel_energy(s.P,cfg);
if show, tigsc.plot_stage('05_mel',s,opts); end
s.logMel = tigsc.log_compress(s.melEnergy);
if show, tigsc.plot_stage('06_logmel',s,opts); end
[M,s.dctBasis] = tigsc.dct_mfcc(s.logMel,cfg);
s.M = M;
if show, tigsc.plot_stage('07_mfcc',s,opts); end
s.features = tigsc.summarize_mfcc(M);
if show, tigsc.plot_stage('08_summary',s,opts); end
end
