from __future__ import annotations

import csv
import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "proposal.md"
OUTPUT_DIR = ROOT / "output" / "pdf"
OUTPUT = OUTPUT_DIR / "ELEC5305_Project_Proposal_Lucas_Wenqi_Wang_550552222.pdf"


def clean(text: str) -> str:
    replacements = {
        "\u2013": "-",
        "\u2014": "-",
        "\u2011": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text.replace("`", "")


def split_sections(markdown: str) -> tuple[str, dict[str, str]]:
    title = re.search(r"^#\s+(.+)$", markdown, re.MULTILINE).group(1)
    parts = re.split(r"^##\s+(.+)$", markdown, flags=re.MULTILINE)
    sections: dict[str, str] = {}
    for i in range(1, len(parts), 2):
        sections[parts[i].strip()] = parts[i + 1].strip()
    return title, sections


def paragraphs(text: str) -> list[str]:
    return [" ".join(block.splitlines()).strip() for block in re.split(r"\n\s*\n", text) if block.strip()]


def add_body(story: list, text: str, body_style: ParagraphStyle) -> None:
    for block in paragraphs(text):
        story.append(Paragraph(html.escape(block), body_style))
        story.append(Spacer(1, 2.3 * mm))


def scaled_image(path: Path, width: float) -> Image:
    from reportlab.lib.utils import ImageReader

    w, h = ImageReader(str(path)).getSize()
    return Image(str(path), width=width, height=width * h / w)


def page_decor(canvas, doc) -> None:
    canvas.saveState()
    page_width, page_height = A4
    canvas.setStrokeColor(colors.HexColor("#D7E1EC"))
    canvas.line(18 * mm, 15 * mm, page_width - 18 * mm, 15 * mm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#5C6B7A"))
    canvas.drawString(18 * mm, 9.5 * mm, "ELEC5305 Project Proposal - Lucas(Wenqi) Wang - SID 550552222")
    canvas.drawRightString(page_width - 18 * mm, 9.5 * mm, f"Page {doc.page}")
    canvas.restoreState()


def build() -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    markdown = clean(SOURCE.read_text(encoding="utf-8"))
    title, sections = split_sections(markdown)

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "TitleCustom",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=26,
        leading=30,
        textColor=colors.HexColor("#12385A"),
        alignment=TA_LEFT,
        spaceAfter=7 * mm,
    )
    subtitle_style = ParagraphStyle(
        "Subtitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=11,
        leading=16,
        textColor=colors.HexColor("#3A596F"),
        spaceAfter=6 * mm,
    )
    h2 = ParagraphStyle(
        "H2Custom",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=15,
        leading=18,
        textColor=colors.HexColor("#1769AA"),
        spaceBefore=4 * mm,
        spaceAfter=2.5 * mm,
        keepWithNext=True,
    )
    body = ParagraphStyle(
        "BodyCustom",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=9.6,
        leading=13.8,
        textColor=colors.HexColor("#172A3A"),
        alignment=TA_LEFT,
        spaceAfter=0,
        allowWidows=0,
        allowOrphans=0,
    )
    small = ParagraphStyle(
        "Small",
        parent=body,
        fontSize=8.2,
        leading=11.2,
        textColor=colors.HexColor("#445566"),
    )
    caption = ParagraphStyle(
        "Caption",
        parent=small,
        fontName="Helvetica-Oblique",
        alignment=TA_CENTER,
        spaceBefore=1.5 * mm,
    )

    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=17 * mm,
        bottomMargin=20 * mm,
        title=title,
        author="Lucas(Wenqi) Wang",
        subject="ELEC5305 Project Proposal",
    )
    story: list = []

    story.append(Paragraph("ELEC5305 Project Proposal", subtitle_style))
    story.append(Paragraph(html.escape(title), title_style))
    story.append(
        Paragraph(
            "A MATLAB study of MFCC front ends, speaker-disjoint evaluation, and compact keyword-spotting models for resource-constrained audio systems.",
            subtitle_style,
        )
    )

    site_url = "https://wenqiwang1314-dotcom.github.io/elec5305-project-550552222/"
    repo_url = "https://github.com/wenqiwang1314-dotcom/elec5305-project-550552222"
    info = [
        [Paragraph("<b>Student</b>", small), Paragraph("Lucas(Wenqi) Wang", small)],
        [Paragraph("<b>Student ID</b>", small), Paragraph("550552222", small)],
        [Paragraph("<b>GitHub username</b>", small), Paragraph("wenqiwang1314-dotcom", small)],
        [Paragraph("<b>Repository</b>", small), Paragraph(f'<link href="{repo_url}" color="#1769AA">{repo_url}</link>', small)],
        [Paragraph("<b>Project site</b>", small), Paragraph(f'<link href="{site_url}" color="#1769AA">{site_url}</link>', small)],
    ]
    info_table = Table(info, colWidths=[35 * mm, 130 * mm], hAlign="LEFT")
    info_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#EFF6FB")),
                ("BOX", (0, 0), (-1, -1), 0.7, colors.HexColor("#B9D4E8")),
                ("INNERGRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#D5E4EF")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(info_table)
    story.append(Spacer(1, 5 * mm))

    for section_name in ["Project Overview", "Background and Motivation", "Proposed Methodology", "Expected Outcomes"]:
        story.append(Paragraph(section_name, h2))
        add_body(story, sections[section_name], body)

    story.append(Paragraph("Timeline (Weeks 1-13)", h2))
    timeline_lines = [line for line in sections["Timeline"].splitlines() if line.startswith("|")]
    timeline_rows = []
    for line in timeline_lines:
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if all(set(cell) <= {"-", ":"} for cell in cells):
            continue
        timeline_rows.append([Paragraph(html.escape(cell), small) for cell in cells])
    timeline = Table(timeline_rows, colWidths=[28 * mm, 137 * mm], repeatRows=1)
    timeline.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1769AA")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F3F7FA")]),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B7C8D6")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(timeline)
    story.append(Spacer(1, 3 * mm))

    story.append(Paragraph("References", h2))
    for line in sections["References"].splitlines():
        if re.match(r"^\d+\.\s", line):
            story.append(Paragraph(html.escape(line), small))
            story.append(Spacer(1, 1.4 * mm))

    story.append(Paragraph("Preliminary Evidence", h2))
    add_body(story, sections["Preliminary Evidence"], body)

    story.append(Paragraph("MFCC Front-End Optimization", h2))
    story.append(
        Paragraph(
            "A controlled ablation keeps the 720/240 manifest and manual 5-NN fixed while changing only the acoustic front end. Clean-trained models are also tested with deterministic 10 dB additive noise. Feature elements are a transparent input-size proxy, not a target-RAM measurement.",
            body,
        )
    )
    story.append(Spacer(1, 2.5 * mm))
    result_path = ROOT / "results" / "mfcc_ablation_results.csv"
    with result_path.open(newline="", encoding="utf-8-sig") as handle:
        result_rows = list(csv.DictReader(handle))
    short_names = {
        "TI_ref_30_20_40_10": "TI reference",
        "MFCC_30_20_40_13": "13 MFCC",
        "MFCC_30_10_40_10": "10 ms hop",
        "MFCC_25_10_40_13": "25/10 ms, 13 MFCC",
        "MFCC_TI_preemphasis": "TI + pre-emphasis",
        "MFCC_TI_CMN": "TI + CMN",
        "MFSC_40_20_20": "20-bin MFSC",
    }
    ablation_data = [[
        Paragraph("<b>Front end</b>", small),
        Paragraph("<b>Shape</b>", small),
        Paragraph("<b>Elements</b>", small),
        Paragraph("<b>Clean</b>", small),
        Paragraph("<b>10 dB</b>", small),
    ]]
    for row in result_rows:
        ablation_data.append([
            Paragraph(html.escape(short_names[row["Variant"]]), small),
            Paragraph(f'{int(float(row["Frames"]))} x {int(float(row["Coefficients"]))}', small),
            Paragraph(str(int(float(row["FeatureElements"]))), small),
            Paragraph(f'{100*float(row["CleanAccuracy"]):.2f}%', small),
            Paragraph(f'{100*float(row["Noise10dBAccuracy"]):.2f}%', small),
        ])
    ablation_table = Table(ablation_data, colWidths=[62 * mm, 24 * mm, 25 * mm, 24 * mm, 24 * mm], repeatRows=1)
    ablation_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1769AA")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F3F7FA")]),
        ("BACKGROUND", (0, 6), (-1, 6), colors.HexColor("#E7F8F7")),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B7C8D6")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
    ]))
    story.append(ablation_table)
    story.append(Spacer(1, 2.5 * mm))
    story.append(Paragraph("CMN reaches 47.08% clean accuracy at the same 490-element input. The near-chance 10 dB results show that noise-aware training is a higher priority than increasing the feature map.", small))

    story.append(Paragraph("Appendix: Preliminary Real-Data Results", h2))
    story.append(
        Paragraph(
            "The following figures were generated by the submitted MATLAB smoke test from held-out Speech Commands v0.02 samples. The result is a 5-NN baseline, not a DSCNN or embedded-device measurement.",
            body,
        )
    )
    story.append(Spacer(1, 3 * mm))
    frontend = scaled_image(ROOT / "results" / "real_audio_frontend.png", 165 * mm)
    story.append(KeepTogether([frontend, Paragraph("Figure A1. Real waveform, STFT, and TI-shaped 49 x 10 MFCC map.", caption)]))
    ablation = scaled_image(ROOT / "results" / "mfcc_ablation_accuracy.png", 165 * mm)
    story.append(KeepTogether([ablation, Paragraph("Figure A2. Controlled front-end accuracy and input-size comparison.", caption)]))
    story.append(PageBreak())
    confusion = scaled_image(ROOT / "results" / "confusion_matrix.png", 155 * mm)
    story.append(KeepTogether([confusion, Paragraph("Figure A3. Speaker-disjoint 12-class smoke-test confusion matrix (240 test samples).", caption)]))

    doc.build(story, onFirstPage=page_decor, onLaterPages=page_decor)
    print(f"PDF_OUTPUT={OUTPUT}")
    return OUTPUT


if __name__ == "__main__":
    build()
