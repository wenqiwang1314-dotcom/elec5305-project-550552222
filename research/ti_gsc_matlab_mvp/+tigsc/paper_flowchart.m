function fig = paper_flowchart(s, opts)
%PAPER_FLOWCHART Draw a publication-style diagram with actual stage outputs.
% The first two rows are the exact implemented numerical path. Solid arrows
% connect computed stages. The dashed downstream box is an explicit future
% integration boundary, not a simulated neural-network inference result.
fig=figure('Color','w','Theme','light','Name','Paper-style MFCC flowchart','NumberTitle','off', ...
    'Visible',opts.visible,'Position',[30 30 1700 1120]);
annotation(fig,'textbox',[.04 .938 .92 .052],'String', ...
    'Single-audio MFCC pipeline', ...
    'EdgeColor','none','FontName','Times New Roman','FontSize',23,'FontWeight','bold');
annotation(fig,'textbox',[.04 .9 .92 .04],'String', ...
    ['Original MATLAB MVP numerical contract | ' opts.label], ...
    'Interpreter','none','EdgeColor','none','FontName','Times New Roman','FontSize',14);
xs=[.04 .285 .53 .775]; w=.185; h=.235; y1=.625; y2=.315;
id=s.selected(ceil(end/2));
for j=1:4
    panel(fig,[xs(j) y1 w h]); panel(fig,[xs(j) y2 w h]);
end
ax=mini(fig,xs(1),y1,w,h,'1  Digitized audio','16000 samples at 16 kHz');
plot(ax,(0:numel(s.x)-1)/s.cfg.fs,s.x,'Color',[.12 .38 .62]);
xlabel(ax,'Time (s)'); ylabel(ax,'Amplitude'); xlim(ax,[0 1]);
ax=mini(fig,xs(2),y1,w,h,'2  Framing','480 samples; 320-sample hop');
plot(ax,0:479,s.frames(:,s.selected)); xlabel(ax,'Sample within frame'); ylabel(ax,'Amplitude');
ax=mini(fig,xs(3),y1,w,h,'3  Hamming window','Symmetric window; no pre-emphasis');
plot(ax,0:479,s.frames(:,id),'Color',[.75 .75 .75]); hold(ax,'on');
plot(ax,0:479,s.windowed(:,id),'Color',[.12 .38 .62]);
xlabel(ax,'Sample within frame'); ylabel(ax,'Amplitude');
ax=mini(fig,xs(4),y1,w,h,'4  FFT','512 points; 257 retained bins');
plot(ax,s.frequency/1000,abs(s.S(:,id)),'Color',[.12 .38 .62]);
xlabel(ax,'Frequency (kHz)'); ylabel(ax,'Magnitude');
ax=mini(fig,xs(4),y2,w,h,'5  Spectral power','P = |FFT|^2 / 512');
plot(ax,s.frequency/1000,s.P(:,id),'Color',[.12 .38 .62]);
xlabel(ax,'Frequency (kHz)'); ylabel(ax,'Power');
ax=mini(fig,xs(3),y2,w,h,'6  Mel filterbank','40 triangles; 20--8000 Hz');
plot(ax,s.frequency/1000,s.filterbank.'); xlabel(ax,'Frequency (kHz)'); ylabel(ax,'Weight');
ax=mini(fig,xs(2),y2,w,h,'7  Natural logarithm','ln(max(BP, 10^{-10}))');
imagesc(ax,s.time,1:40,s.logMel); axis(ax,'xy');
xlabel(ax,'Frame center (s)'); ylabel(ax,'Mel filter');
ax=mini(fig,xs(1),y2,w,h,'8  Orthonormal DCT-II','Retain c0--c9: 49 x 10 MFCC');
imagesc(ax,s.time,0:9,s.M.'); axis(ax,'xy');
xlabel(ax,'Frame center (s)'); ylabel(ax,'MFCC order');
for j=1:3
    arrow(fig,[xs(j)+w+.006 xs(j+1)-.006],[y1+h/2 y1+h/2]);
    arrow(fig,[xs(j+1)-.006 xs(j)+w+.006],[y2+h/2 y2+h/2]);
end
arrow(fig,[xs(4)+w/2 xs(4)+w/2],[y1-.008 y2+h+.008]);
arrow(fig,[xs(1)+w/2 xs(1)+w/2],[y2-.006 .237]);
% The final row communicates the output contract without implying that an
% unavailable neural network generated class probabilities for this audio.
panel(fig,[.04 .105 .285 .13]);
txt(fig,[.05 .171 .265 .05],'9  Feature tensor / CSV',16,true);
txt(fig,[.05 .115 .265 .062],sprintf('49 frames x 10 coefficients\nSemantic NCHW: [1, 1, 49, 10]'),13,false);
panel(fig,[.385 .105 .285 .13]);
txt(fig,[.395 .171 .265 .05],'10  Explicit float32 export',16,true);
txt(fig,[.395 .115 .265 .062],sprintf('Frame-major; c0...c9 per frame\n490 values; 1960 bytes; round-trip checked'),12,false);
annotation(fig,'rectangle',[.73 .105 .23 .13],'LineStyle','--','LineWidth',1.5,'Color',[.4 .4 .4]);
txt(fig,[.74 .171 .21 .05],'TI model integration',16,true);
txt(fig,[.74 .112 .21 .065],sprintf('Quantization / DSCNN / NPU\nNot implemented in this MVP'),12,false);
arrow(fig,[.332 .378],[.17 .17]);
annotation(fig,'arrow',[.678 .723],[.17 .17],'LineStyle','--','LineWidth',1.4);
txt(fig,[.04 .025 .92 .055],sprintf(['Solid arrows: computed on the same audio. Heatmaps show actual values; see stage figures for color scales.\n' ...
    'Baseline-only branch: MFCC mean/std -> training standardization -> centroid distance -> argmin (synthetic model).']),12,false);
drawnow;
colormap(fig,parula(256));
exportgraphics(fig,fullfile(opts.outDir,'paper_pipeline.png'),'Resolution',220);
exportgraphics(fig,fullfile(opts.outDir,'paper_pipeline.pdf'),'ContentType','vector');
exportgraphics(fig,fullfile(opts.outDir,'paper_pipeline.svg'),'ContentType','vector');
savefig(fig,fullfile(opts.outDir,'paper_pipeline.fig'));
end

function panel(fig,pos)
annotation(fig,'rectangle',pos,'LineWidth',1.3,'Color',[.15 .15 .15]);
end
function ax=mini(fig,x,y,w,h,titleText,subtitle)
txt(fig,[x+.005 y+h-.047 w-.01 .04],titleText,16,true);
txt(fig,[x+.005 y+h-.08 w-.01 .032],subtitle,11,false);
ax=axes(fig,'Position',[x+.039 y+.051 w-.052 h-.138]);
set(ax,'FontName','Times New Roman','FontSize',10,'Box','on');
end
function txt(fig,pos,str,sz,bold)
weight='normal'; if bold, weight='bold'; end
annotation(fig,'textbox',pos,'String',str,'EdgeColor','none', ...
    'FontName','Times New Roman','FontSize',sz,'FontWeight',weight,'HorizontalAlignment','center');
end
function arrow(fig,x,y)
annotation(fig,'arrow',x,y,'LineWidth',1.8,'HeadWidth',10,'HeadLength',10);
end
