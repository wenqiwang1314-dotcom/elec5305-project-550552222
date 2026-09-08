function cfg = config()
%CONFIG Central numerical contract copied from the original MATLAB MVP.
% These settings preserve that implementation; shape agreement alone does
% not establish numerical equivalence to a TI SDK or a quantized NPU model.
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
end
