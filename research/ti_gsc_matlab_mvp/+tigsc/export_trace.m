function s = export_trace(s, opts)
%EXPORT_TRACE Save each stage and a precisely documented float32 layout.
% CSV rows/columns are not silently flattened: MFCC CSV is [frame, coeff].
% MATLAB M(:) would order frames fastest and is NOT the order chosen here.
% Transpose first to write c0..c9 per frame, then advance the frame index.
% This file is an inspectable unquantized interchange example. A concrete
% TI model's scale, zero point, dtype and input layout must be checked before
% deployment; no compatibility with an unspecified NPU binary is implied.
out=opts.outDir;
names={'frames','windowed','P','filterbank','melEnergy','logMel','dctBasis','M','features'};
for i=1:numel(names)
    writematrix(s.(names{i}),fullfile(out,[names{i} '.csv']));
end
writematrix(real(s.S),fullfile(out,'fft_real.csv'));
writematrix(imag(s.S),fullfile(out,'fft_imag.csv'));
s.packed=reshape(single(s.M.'),[],1);
binaryPath=fullfile(out,'mfcc_frame_major_f32le.bin');
fid=fopen(binaryPath,'w','ieee-le'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid));
count=fwrite(fid,s.packed,'single'); assert(count==numel(s.M));
clear cleanup;
fid=fopen(binaryPath,'r','ieee-le'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid));
readback=fread(fid,Inf,'*single'); clear cleanup;
recovered=reshape(readback,s.cfg.num_mfcc,[]).';
assert(isequal(recovered,single(s.M)),'Binary layout round-trip failed.');
meta=struct('sample_rate_hz',s.cfg.fs,'frame_samples',480,'hop_samples',320, ...
    'nfft',s.cfg.nfft,'mel_filters',s.cfg.num_mel,'mel_min_hz',20, ...
    'mel_max_hz',s.cfg.fs/2,'log_base','e','energy_floor',1e-10, ...
    'window','symmetric Hamming','dct','orthonormal type II, c0 through c9', ...
    'mfcc_csv_shape',size(s.M),'semantic_nchw_shape',[1 1 size(s.M)], ...
    'binary_dtype','float32 little endian','binary_order','frame-major, coefficient-fastest', ...
    'binary_values',numel(s.packed),'binary_bytes',4*numel(s.packed), ...
    'binary_roundtrip_pass',true,'npu_quantization','not performed', ...
    'compatibility_scope','Original MATLAB MVP; TI SDK numerical parity is unverified');
if isfield(opts,'source'), meta.audio_source=opts.source; end
fid=fopen(fullfile(out,'feature_contract.json'),'w'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,'%s\n',jsonencode(meta,PrettyPrint=true));
clear cleanup;
save(fullfile(out,'stage_data.mat'),'s','meta');
tigsc.plot_stage('09_export',s,opts);
end
