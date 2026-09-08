function fig = plot_stage(stage, s, opts)
%PLOT_STAGE Display a module's actual output, then save PNG and editable FIG.
% All frequency/time axes come from the same sample/frame indices used in
% computation. Display-only dB conversions never feed the MFCC computation.
if ~isfolder(opts.outDir), mkdir(opts.outDir); end
if ~isfield(opts,'visible'), opts.visible='on'; end
fig=figure('Color','w','Theme','light','Name',stage,'NumberTitle','off', ...
    'Visible',opts.visible,'Position',[60 60 1250 800]);
cfg=s.cfg;
switch stage
    case '00_audio'
        tiledlayout(fig,2,1,'TileSpacing','compact');
        nexttile; plot((0:numel(s.x)-1)/cfg.fs,s.x,'Color',[.12 .38 .62]);
        xlabel('Time (s)'); ylabel('Amplitude (full scale)'); grid on;
        title('01 | Input waveform: no pre-emphasis or amplitude normalization');
        nexttile; plot((0:min(799,numel(s.x)-1))/cfg.fs, ...
            s.x(1:min(800,numel(s.x)))); grid on;
        xlabel('Time (s)'); ylabel('Amplitude'); title('First 50 ms (sample-level view)');
    case '01_framing'
        tiledlayout(fig,2,3,'TileSpacing','compact');
        nexttile([1 3]); plot((0:numel(s.x)-1)/cfg.fs,s.x,'k'); hold on;
        colors=lines(numel(s.selected)); yl=ylim;
        for j=1:numel(s.selected)
            id=s.selected(j); a=(s.sampleIndex(1,id)-1)/cfg.fs;
            b=(s.sampleIndex(end,id)-1)/cfg.fs;
            patch([a b b a],yl([1 1 2 2]),colors(j,:), ...
                'FaceAlpha',.2,'EdgeColor',colors(j,:));
        end
        xlabel('Time (s)'); ylabel('Amplitude'); grid on;
        title(sprintf('02 | %d complete frames: L=480, H=320; final 160 samples unused',size(s.frames,2)));
        for j=1:numel(s.selected)
            nexttile; plot(0:size(s.frames,1)-1,s.frames(:,s.selected(j)), ...
                'Color',colors(j,:)); grid on;
            xlabel('Sample within frame'); ylabel('Amplitude');
            title(sprintf('Frame %d (1-based)',s.selected(j)));
        end
    case '02_window'
        tiledlayout(fig,2,3,'TileSpacing','compact');
        nexttile([1 3]); plot(0:numel(s.window)-1,s.window,'k','LineWidth',1.5);
        grid on; xlabel('Sample within frame'); ylabel('Window weight');
        title('03 | Symmetric Hamming window: denominator L-1');
        for j=1:numel(s.selected)
            nexttile; id=s.selected(j);
            plot(0:479,s.frames(:,id),'Color',[.7 .7 .7]); hold on;
            plot(0:479,s.windowed(:,id),'Color',[.12 .38 .62]); grid on;
            xlabel('Sample within frame'); ylabel('Amplitude');
            title(sprintf('Windowed frame %d',id));
            if j==1, legend('Before','After','Location','best'); end
        end
    case '03_fft'
        tiledlayout(fig,2,2,'TileSpacing','compact'); id=s.selected(ceil(end/2));
        nexttile; plot(0:cfg.nfft-1,[s.windowed(:,id);zeros(cfg.nfft-480,1)]);
        xline(479.5,'--'); xlabel('Sample index'); ylabel('Amplitude'); grid on;
        title('04 | 480 windowed samples + 32 zero samples');
        nexttile; plot(s.frequency,abs(s.S(:,id))); grid on;
        xlabel('Frequency (Hz)'); ylabel('|FFT|'); title(sprintf('Frame %d: magnitude',id));
        nexttile; plot(s.frequency,angle(s.S(:,id))); grid on;
        xlabel('Frequency (Hz)'); ylabel('Phase (rad)'); title('Complex FFT phase');
        nexttile; heat(s.time,s.frequency,20*log10(abs(s.S)+1e-8), ...
            'Time (s; frame centers)','Frequency (Hz)','Magnitude display: 20 log10(|S|+1e-8)','dB');
    case '04_power'
        tiledlayout(fig,2,1,'TileSpacing','compact'); id=s.selected(ceil(end/2));
        nexttile; plot(s.frequency,s.P(:,id)); grid on;
        xlabel('Frequency (Hz)'); ylabel('|FFT|^2 / 512');
        title('05 | Spectral power: no one-sided doubling, no PSD normalization');
        nexttile; heat(s.time,s.frequency,10*log10(max(s.P,1e-12)), ...
            'Time (s; frame centers)','Frequency (Hz)','Power map (display only in dB)','dB');
    case '05_mel'
        tiledlayout(fig,2,1,'TileSpacing','compact');
        nexttile; plot(s.frequency,s.filterbank.'); grid on;
        xlabel('Frequency (Hz)'); ylabel('Filter weight');
        title('06 | 40 triangular Mel filters, 20--8000 Hz, no area normalization');
        nexttile; heat(s.time,1:cfg.num_mel,s.melEnergy, ...
            'Time (s; frame centers)','Mel filter index','Linear Mel energies: E = B P (40 x 49)','Energy');
    case '06_logmel'
        tiledlayout(fig,2,1,'TileSpacing','compact');
        nexttile; heat(s.time,1:cfg.num_mel,s.logMel, ...
            'Time (s; frame centers)','Mel filter index', ...
            '07 | Log-Mel: ln(max(E, 1e-10)); not MFCC yet','Natural log energy');
        nexttile; id=s.selected(ceil(end/2)); plot(1:cfg.num_mel,s.logMel(:,id),'-o');
        grid on; xlabel('Mel filter index'); ylabel('Natural log energy');
        title(sprintf('Log-Mel vector for frame %d',id));
    case '07_mfcc'
        tiledlayout(fig,3,1,'TileSpacing','compact');
        nexttile; heat(0:cfg.num_mel-1,0:cfg.num_mfcc-1,s.dctBasis, ...
            'Mel index q (0-based)','DCT order k','08 | Orthonormal DCT-II basis, c0 retained','Basis weight');
        nexttile; heat(s.time,0:cfg.num_mfcc-1,s.M.', ...
            'Time (s; frame centers)','MFCC order (c0--c9)','MFCC = (C logMel)^T: 49 frames x 10 coefficients','Coefficient');
        % c0 has a different range. A separate display of c1--c9 makes their
        % variation readable without normalizing or changing exported MFCCs.
        nexttile; heat(s.time,1:cfg.num_mfcc-1,s.M(:,2:end).', ...
            'Time (s; frame centers)','MFCC order (c1--c9)', ...
            'Detail view only: c0 omitted from this panel; exported matrix is unchanged','Coefficient');
    case '08_summary'
        tiledlayout(fig,2,1,'TileSpacing','compact');
        nexttile; bar(0:9,s.features(1:10)); grid on;
        xlabel('MFCC order'); ylabel('Temporal mean');
        title('09 | Optional centroid-baseline branch: 20 summary values');
        nexttile; bar(0:9,s.features(11:20)); grid on;
        xlabel('MFCC order'); ylabel('Sample standard deviation (N-1)');
        title('The full 49 x 10 map is exported separately');
    case '09_export'
        tiledlayout(fig,2,1,'TileSpacing','compact');
        nexttile; heat(1:size(s.M,1),0:9,s.M.', ...
            'Frame index (1-based)','MFCC order','10 | Frame-major packing: c0...c9 of frame 1, then frame 2...','Coefficient');
        nexttile; stairs(0:numel(s.packed)-1,double(s.packed)); grid on;
        xlim([0 numel(s.packed)-1]); xlabel('Zero-based float32 element offset'); ylabel('MFCC');
        title('490 float32 values; explicit demonstration layout, not an SDK binary claim');
    case '10_classifier'
        tiledlayout(fig,2,1,'TileSpacing','compact');
        nexttile; bar(s.Z); grid on; xlabel('Summary feature index'); ylabel('Standardized value');
        title('11 | Apply training-only mean and standard deviation');
        nexttile; bar(s.D); grid on; xticks(1:numel(cfg.labels));
        xticklabels(cfg.labels); xtickangle(30); ylabel('Mean squared distance (lower is better)');
        title(sprintf('Synthetic centroid baseline: prediction = %s; distances are not posteriors',cfg.labels(s.pred)), ...
            'Interpreter','none');
end
set(findall(fig,'Type','axes'),'FontName','Times New Roman','FontSize',11);
colormap(fig,parula(256));
if isfield(opts,'label')
    sgtitle(opts.label,'Interpreter','none','FontName','Times New Roman','FontSize',15);
end
drawnow;
exportgraphics(fig,fullfile(opts.outDir,[stage '.png']),'Resolution',170);
savefig(fig,fullfile(opts.outDir,[stage '.fig']));
end

function heat(x,y,z,xlabelText,ylabelText,titleText,colorText)
imagesc(x,y,z); axis xy; xlabel(xlabelText); ylabel(ylabelText);
title(titleText); cb=colorbar; cb.Label.String=colorText;
end
