"""Build the Feedback Two PDF/site/brief from measured results, never guessed metrics."""
from __future__ import annotations
import csv
import hashlib
import html
import json
import re
import shutil
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak

ROOT = Path(__file__).resolve().parents[1]
RESULT = ROOT / "results/feedback_two"
SITE = "https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/"
REPO = "https://github.com/wenqiwang1314-dotcom/elec5305-project-550552222"
PDF_NAME = "ELEC5305_Feedback_Two_Lucas_Wenqi_Wang_550552222.pdf"


def build():
    s = json.loads((RESULT / "summary.json").read_text())
    rounds = list(csv.DictReader((RESULT / "timing_rounds.csv").open()))
    assert s["pass"] and s["audioCount"] == s["exactMatches"] == 960
    a, b, ratio = s["uncachedMedianMs"], s["cachedMedianMs"], s["speedupRatioOfMedians"]
    saving = 100*(1-b/a)
    sections = [
      ("Project overview", [
        "This project studies how digital signal processing before a neural network can make keyword spotting more efficient. The task has ten commands, unknown speech and silence. The research question is which conditioning, time-frequency features and model structure retain useful speech information at the lowest total processing cost. The target design follows TI's DSCNN example; MATLAB provides an inspectable prototype. This update reports completed code and measurements for Project Feedback Two, together with the remaining work."]),
      ("Background and method", [
        "MFCCs summarize the speech spectral envelope using short-time analysis, a perceptual Mel filterbank, logarithmic compression and a cosine transform [1,2]. Depthwise-separable convolutions offer a compact downstream classifier [3]. Robust compression such as PCEN motivates later noise experiments [4]. The design must account for both feature extraction and inference, because reducing model size alone does not remove preprocessing cost.",
        "The reference accepts 16 kHz mono audio adapted to 16,000 samples. A symmetric 480-sample Hamming window and 320-sample hop give 49 complete frames. A 512-point FFT feeds 40 triangular Mel filters spanning 20 Hz to Nyquist. Natural-log compression with a 1e-10 floor and orthonormal DCT-II retain c0-c9, giving a 49-by-10 map. TI [5] specifies the shape; numerical equivalence to its SDK remains to be established."]),
      ("Completed implementation and data", [
        "The repository now contains independently inspectable MATLAB stages, a real yes-recording walkthrough, intermediate arrays, float32 tensor export, and configurable PlotNeuralNet architecture figures. Earlier frozen-reference regression evidence covers 53 probes. The model diagram documents geometry; trained DSCNN weights are still pending.",
        "Twelve licensed archives provide 720 training and 240 test examples with source and SHA-256 manifests. The existing speech split audit found zero speaker overlap; background source recordings are separated by split. Re-auditing durations found 84 short clips and 876 clips of 16,000 samples. The new adapter right-pads short recordings before processing, preserving the distributed source files. This corrects the previous website claim that every raw recording contained exactly one second."]),
      ("New experiment: equivalent cached MFCC", [
        "The implementation precomputes the Hamming window, Mel weights and DCT basis in an explicit configuration-specific plan. A feature-only kernel reuses those constants. Its output was compared with the original modular frontend on all 960 published recordings after identical duration adaptation. All maps matched exactly. Five additional probes cover zero, impulse, sinusoid, random noise and near-zero input; malformed inputs are rejected and a rebuilt 13-coefficient configuration also matches.",
        "The timing comparison uses the same feature-only kernel in both paths: one rebuilds the plan per clip, the other reuses it. Both paths are warmed up; nine rounds alternate execution order over 120 evenly spaced manifest entries. Reading, hashing, padding, plots and classification are excluded. All per-round measurements and input indices are published. The host is an Intel Core i7-11800H running MATLAB R2026a Update 4 with default threading.",
        f"Median batch-average time falls from {a:.3f} to {b:.3f} ms per clip: {ratio:.2f}x speedup, or {saving:.1f}% less time. Setup separately takes a median {s['medianSetupMs']:.3f} ms. Cached double-precision constants occupy {s['constantPayloadBytes']:,} bytes, excluding scratch arrays, FFT internals and object overhead. Thus caching has a storage cost; sparse filters and constant placement need evaluation before embedded deployment."]),
      ("Earlier recognition results and limitations", [
        "The earlier fixed-subset 5-NN diagnostic achieved 39.17% clean accuracy; cepstral mean normalization reached 47.08% with the same 490-element feature map. The classifier used 90 summary values (mean, standard deviation and seven temporal bins), not the raw map. Clean-trained variants fell to 8.33-10.42% under deterministic 10 dB Gaussian noise; unknown recall was 0-5%. These motivate noise-aware training and rejection.",
        "Those exploratory comparisons exposed the small test subset during development, so they cannot establish an unbiased final model ranking. New model selection will use official validation data. The caching result proves numerical preservation and PC timing only; it adds no new recognition score. Shared-desktop timing varies, and exact parity on this corpus does not prove cross-platform parity or energy savings."]),
      ("Remaining work and requested feedback", [
        "Weeks 10-11: benchmark compact constant storage, implement a train/validation/test pipeline, and compare the same small DSCNN with baseline MFCC and CMN under matched noise augmentation. Weeks 12-13: repeat feasible comparisons with three seeds, report accuracy and memory alongside frontend cost, and finish documentation. INT8 golden tensors and TI compilation follow only after the floating-point model is validated; hardware timing and energy are stretch goals.",
        "Feedback is requested on whether the bounded MFCC-versus-CMN comparison provides sufficient scope, whether cached dense filters should be replaced by sparse accumulation before model training, and which unknown-rejection metrics are most useful. The immediate deliverable is a reproducible MATLAB study with traceable results. This staged scope keeps the project feasible without presenting a planned deployment as completed work."]),
      ("Assistance disclosure", [
        "OpenAI Codex assisted with code, experiment orchestration, documentation and formatting. The reported new measurements were produced by executing MATLAB. Source code, configurations and results are retained for inspection; the student remains responsible for reviewing the material and complying with course rules before submission."]),
    ]
    refs = [
      '[1] S. B. Davis and P. Mermelstein, "Comparison of Parametric Representations for Monosyllabic Word Recognition in Continuously Spoken Sentences," IEEE TASSP, 1980. doi:10.1109/TASSP.1980.1163420.',
      '[2] T. Giannakopoulos and A. Pikrakis, Introduction to Audio Analysis: A MATLAB Approach, Chapter 4, 2014. doi:10.1016/B978-0-08-099388-1.00004-2.',
      '[3] P. M. Sorensen, B. Epp and T. May, "A Depthwise Separable Convolutional Neural Network for Keyword Spotting on an Embedded System," EURASIP JASMP, 2020. doi:10.1186/s13636-020-00176-2.',
      '[4] Y. Wang et al., "Trainable Frontend for Robust and Far-Field Keyword Spotting," ICASSP, 2017. doi:10.1109/ICASSP.2017.7953242.',
      '[5] Texas Instruments, "Google Speech Command Recognition," Tiny ML Tensorlab 1.4.0, sections 7.8.30.6-7. Accessed 9 October 2026; linked on the project page.',
    ]
    body_words = len(re.findall(r"\S+", " ".join(p for _, ps in sections for p in ps)))
    assert 700 <= body_words <= 1000, body_words
    timing = [["Measure", "Observed result"],
       ["Exact real-audio MFCC matches", "960 / 960; maximum error 0"],
       ["Uncached / cached median", f"{a:.3f} / {b:.3f} ms per clip"],
       ["Ratio of medians", f"{ratio:.2f}x; {saving:.1f}% lower time"],
       ["Constant numeric payload", f"{s['constantPayloadBytes']:,} bytes (double precision)"]]
    plot = ROOT / "docs/assets/feedback_two_timing.png"
    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})
    fig, ax = plt.subplots(figsize=(8.0,2.7), constrained_layout=True)
    x=[int(r["Round"]) for r in rounds]
    ax.plot(x,[float(r["UncachedMsPerClip"]) for r in rounds],"o-",color="#1769aa",label="Rebuild constants per clip")
    ax.plot(x,[float(r["CachedMsPerClip"]) for r in rounds],"s-",color="#148575",label="Reuse cached constants")
    ax.set(xlabel="Alternating-order timing round (120 clips each)",ylabel="Batch-average ms / clip",ylim=(0,None),xticks=x)
    ax.legend(loc="lower left",frameon=False,ncol=2);ax.grid(axis="y",alpha=.2)
    fig.savefig(plot,dpi=180);plt.close(fig)
    pdf=ROOT / "output/pdf" / PDF_NAME; pdf.parent.mkdir(parents=True,exist_ok=True)
    styles=getSampleStyleSheet()
    body=ParagraphStyle("FBBody",parent=styles["BodyText"],fontName="Helvetica",fontSize=9.5,leading=13,spaceAfter=7)
    heading=ParagraphStyle("FBHeading",parent=styles["Heading2"],fontSize=12,leading=15,spaceBefore=8,spaceAfter=6,textColor=colors.HexColor("#1769aa"))
    small=ParagraphStyle("FBSmall",parent=body,fontSize=8,leading=10.5,spaceAfter=5)
    title=ParagraphStyle("FBTitle",parent=styles["Title"],fontSize=22,leading=25,alignment=0,textColor=colors.HexColor("#12385a"),spaceAfter=10)
    def para(text,style=body): return Paragraph(html.escape(text),style)
    def add_section(story,i):
        h,ps=sections[i];story.append(para(h,heading));story.extend(para(p) for p in ps)
    def decorate(canvas,doc):
        canvas.setFont("Helvetica",8);canvas.setFillColor(colors.HexColor("#596579"))
        canvas.drawString(18*mm,11*mm,"ELEC5305 | Project Feedback Two | 550552222 | 9 October 2026")
        canvas.drawRightString(192*mm,11*mm,f"{doc.page}")
    story=[para("PROJECT FEEDBACK TWO",small),para("DSP Front-End and DSCNN Co-Optimization for Keyword Spotting",title),
        para("Lucas(Wenqi) Wang | SID 550552222 | GitHub: wenqiwang1314-dotcom",body),
        Paragraph(f'<b>Project site:</b> <link href="{SITE}" color="#1769aa">{SITE}</link>',small),
        Paragraph(f'<b>Progress and code:</b> <link href="{SITE}feedback-two.html" color="#1769aa">{SITE}feedback-two.html</link>',small),
        Paragraph(f'<b>Repository:</b> <link href="{REPO}" color="#1769aa">{REPO}</link>',small)]
    for i in (0,1,2):add_section(story,i)
    story.append(PageBreak());add_section(story,3)
    data=[[para(c,small) for c in row] for row in timing]
    table=Table(data,colWidths=[80*mm,90*mm],hAlign="LEFT")
    table.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,0),colors.HexColor("#e8f2f9")),("ROWBACKGROUNDS",(0,1),(-1,-1),[colors.white,colors.HexColor("#f4f7fa")]),("VALIGN",(0,0),(-1,-1),"TOP"),("LEFTPADDING",(0,0),(-1,-1),7),("TOPPADDING",(0,0),(-1,-1),5),("BOTTOMPADDING",(0,0),(-1,-1),3)]))
    story.extend([Spacer(1,3*mm),table,Spacer(1,5*mm),Image(str(plot),width=170*mm,height=57.375*mm),para("Figure 1. Individual timing rounds on the same PC; lower is faster. Raw measurements and configuration are linked from the progress page.",small)])
    story.append(PageBreak())
    for i in (4,5):add_section(story,i)
    story.append(para("References",heading));story.extend(para(r,small) for r in refs)
    add_section(story,6)
    doc=SimpleDocTemplate(str(pdf),pagesize=A4,leftMargin=18*mm,rightMargin=18*mm,topMargin=16*mm,bottomMargin=20*mm,title="ELEC5305 Project Feedback Two",author="Lucas(Wenqi) Wang")
    doc.build(story,onFirstPage=decorate,onLaterPages=decorate)
    download=ROOT/"docs/downloads"/PDF_NAME;download.parent.mkdir(exist_ok=True);shutil.copyfile(pdf,download)
    blocks=[]
    for idx,(h,ps) in enumerate(sections):
        part='<section><h2>'+html.escape(h)+'</h2>'+''.join('<p>'+html.escape(p)+'</p>' for p in ps)
        if idx==3:
            part+='<table class="results"><tbody>'+''.join('<tr>'+''.join('<'+('th' if n==0 else 'td')+'>'+html.escape(c)+'</'+('th' if n==0 else 'td')+'>' for c in row)+'</tr>' for n,row in enumerate(timing))+'</tbody></table>'
            part+='<figure><img src="assets/feedback_two_timing.png" alt="Uncached and cached batch-average latency across nine timing rounds"><figcaption>120 clips per round; shared desktop PC, default MATLAB threading.</figcaption></figure>'
        blocks.append(part+'</section>')
    source_links=[('Benchmark MATLAB script','research/ti_gsc_matlab_mvp/benchmark_cached_frontend.m'),('Cached feature kernel','research/ti_gsc_matlab_mvp/+tigsc/frontend_cached.m'),('Constant preparation','research/ti_gsc_matlab_mvp/+tigsc/prepare_frontend.m'),('960-row parity audit','results/feedback_two/cached_parity.csv'),('Nine timing rounds','results/feedback_two/timing_rounds.csv'),('Machine-readable summary','results/feedback_two/summary.json'),('Earlier recognition results','results/mfcc_ablation_results.csv')]
    blocks.append('<section><h2>Reproduce and inspect</h2><pre><code>addpath(fullfile(\'research\',\'ti_gsc_matlab_mvp\'))\nbenchmark_cached_frontend</code></pre><p>Run from the repository root. The checked-in archives supply the audio; no private dataset path is required.</p><ul>'+''.join(f'<li><a href="{REPO}/blob/main/{path}">{name}</a></li>' for name,path in source_links)+'</ul></section>')
    blocks.append('<section><h2>References</h2>'+''.join('<p>'+html.escape(r)+'</p>' for r in refs)+'<p><a href="https://software-dl.ti.com/C2000/esd/mcu_ai/01_04_00/user_guide/examples/google_speech_command.html">TI official MFCC and DSCNN reference</a></p></section>')
    document='''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="ELEC5305 Project Feedback Two: completed MATLAB DSP work, cached MFCC equivalence, measured timing and research next steps."><title>Project Feedback Two | ELEC5305</title><link rel="stylesheet" href="styles.css"></head><body><header class="compact"><div class="tag">9 October 2026</div><div class="tag">Measured MATLAB progress</div><h1>Project Feedback Two</h1><p>DSP Front-End and DSCNN Co-Optimization for Keyword Spotting</p><p>Lucas(Wenqi) Wang · SID 550552222</p><p class="actions"><a class="button" href="downloads/'''+PDF_NAME+'''">Download submission PDF</a><a class="button secondary" href="index.html">Project home</a><a class="button secondary" href="dsp-model-codesign.html">DSP walkthrough</a><a class="button secondary" href="dataset.html">Dataset</a></p></header><main>'''+''.join(blocks)+'''</main><footer>ELEC5305 · Evidence current to 9 October 2026</footer></body></html>'''
    (ROOT/"docs/feedback-two.html").write_text(document,encoding="utf-8")
    brief=(f"Lucas(Wenqi) Wang | SID 550552222\nProject Feedback Two\n\n"
      "This project investigates efficient audio preprocessing and DSCNN co-design for 12-class keyword spotting. "
      "Completed work includes a modular MATLAB MFCC pipeline, real-audio stage visualizations, licensed reproducible data and an earlier 5-NN feature study. "
      f"A new cached frontend reproduced all 960 reference MFCC maps exactly and reduced median PC processing time from {a:.3f} to {b:.3f} ms per clip ({ratio:.2f}x). "
      "The earlier CMN diagnostic reached 47.08% clean accuracy; noise robustness and unknown rejection remain priorities. "
      "The project site documents code, measurements, limitations and next steps. DSCNN training and TI hardware validation remain future work. "
      "OpenAI Codex assisted with implementation, documentation and experiment execution, as disclosed in the attached progress report.\n\n"
      f"GitHub Project Site: {SITE}\nProgress: {SITE}feedback-two.html\nRepository: {REPO}\n")
    (ROOT/"SUBMISSION_FEEDBACK_TWO.txt").write_text(brief,encoding="utf-8")
    (RESULT/"report_build.json").write_text(json.dumps({"narrativeWords":body_words,"pdfSHA256":hashlib.sha256(pdf.read_bytes()).hexdigest(),"summarySHA256":hashlib.sha256((RESULT/"summary.json").read_bytes()).hexdigest()},indent=2)+"\n")
    print(f"PDF_OUTPUT={pdf}\nNARRATIVE_WORDS={body_words}\nFEEDBACK_TWO_BUILD_PASS=1")

if __name__=="__main__": build()
