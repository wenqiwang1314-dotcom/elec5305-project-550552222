"""Generate DSCNN diagrams with the real, pinned PlotNeuralNet library.

Edit model.json for architecture and style.json for appearance. The graph is
built from operators and computed tensor shapes, never from hard-coded shape
labels. Third-party pycore and TikZ layers remain unchanged in vendor/.

The generator uses PlotNeuralNet's to_head, to_begin, to_connection and
to_generate, together with its Box and RightBandedBox TikZ primitives. Thin
green right bands represent BN followed by ReLU, not another convolution.
This is a figure generator, not a trainable network implementation.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VENDOR = ROOT / "vendor" / "PlotNeuralNet"
sys.path.insert(0, str(VENDOR))
from pycore.tikzeng import to_head, to_begin, to_connection, to_end, to_generate


def conv_shape(shape, out_channels, kernel, stride, padding):
    """Conv2d output for dilation=1; tensor convention is C x T x F."""
    assert all(isinstance(v, int) and v > 0 for v in (*shape, out_channels, *kernel, *stride))
    assert all(isinstance(v, int) and v >= 0 for v in padding)
    spatial = tuple((shape[i + 1] + 2 * padding[i] - kernel[i]) // stride[i] + 1 for i in range(2))
    if min(spatial) < 1:
        raise ValueError(f"Convolution collapses its input: {shape}, {kernel}, {stride}, {padding}")
    return (out_channels, *spatial)


def inspect_model(m):
    """Expand the serialized architecture; repeated blocks have own weights.

    A depthwise layer retains the incoming channel count and uses that count
    as groups. Its pointwise layer may change channels, so future width and
    stride variants can be represented without rewriting the drawing code.
    """
    if not m["ds_blocks"]:
        raise ValueError("At least one DS block is required by this diagram template.")
    assert isinstance(m["classes"], int) and m["classes"] > 0
    assert len(m["dropout"]) == 2 and all(0 <= p < 1 for p in m["dropout"])
    inp = m["input"]
    current = (inp["channels"], inp["time"], inp["features"])
    rows = [{"name": "input", "output": current}]
    stem = m["stem"]
    current = conv_shape(current, stem["channels"], stem["kernel"], stem["stride"], stem["padding"])
    rows.append({"name": "stem", "output": current})
    blocks = []
    for i, spec in enumerate(m["ds_blocks"], 1):
        assert isinstance(spec["channels"], int) and spec["channels"] > 0
        before = current
        dw = conv_shape(current, current[0], spec["kernel"], spec["stride"], spec["padding"])
        current = (spec["channels"], dw[1], dw[2])
        blocks.append({"index": i, "input": before, "depthwise": dw, "output": current, "groups": before[0], **spec})
        rows += [{"name": f"ds{i}_dw", "output": dw}, {"name": f"ds{i}_pw", "output": current}]
    rows += [{"name": "pool", "output": (current[0], 1, 1)},
             {"name": "flatten", "output": (current[0],)}, {"name": "logits", "output": (m["classes"],)}]
    return rows, blocks


def tex_escape(s):
    return str(s).replace("_", r"\_")


def dimensions(shape):
    return "$" + r"\!\times\!".join(map(str, shape)) + "$"


def pair(v):
    return r"\times".join(map(str, v))


def node(x, y, text, extra=""):
    return rf"\node[align=center,{extra}] at ({x:.4f},{y:.4f},0) {{{text}}};" + "\n"


def box(name, x, width, height, depth, color, st, band=False):
    """Use original PlotNeuralNet geometry; custom labels are aligned outside.

    Native captions use width-dependent wrapping, which is unsuitable for
    thin depthwise/dropout plates. Empty native labels plus separate TikZ
    nodes keep the same 3-D renderer and give predictable scientific layout.
    """
    kind = "RightBandedBox" if band else "Box"
    # PGF's array parser needs a second element even for a single cuboid.
    # Only the first (empty) label is used; the dummy is never rendered.
    keys = [f"name={name}", 'xlabel={{"","dummy"}}', "caption={}", "ylabel={}", "zlabel={}",
            f"fill={color}", f"opacity={st['opacity']}",
            f"width={width:.4f}", f"height={height:.4f}", f"depth={depth:.4f}"]
    if band:
        keys += ["bandfill=BNColor", "bandopacity=0.95"]
    return rf"\pic at ({x:.4f},0,0) {{{kind}={{{','.join(keys)}}}}};" + "\n"


def preamble(st, out):
    # Relative imports keep the entire folder portable, including Overleaf.
    import os
    try:
        relative = os.path.relpath(VENDOR, out).replace("\\", "/")
    except ValueError:
        # Windows cannot form a relative path across different drive letters.
        relative = VENDOR.as_posix()
    head = to_head(relative)
    head = head.replace("border=8pt", "border=12pt")
    head += "\n\\usepackage{newtxtext,newtxmath}\n\\usetikzlibrary{calc,decorations.pathreplacing}\n"
    head += "\n".join(rf"\definecolor{{{k}}}{{HTML}}{{{v}}}" for k, v in st["colors"].items())
    begin = to_begin().replace(r"\begin{tikzpicture}", rf"\begin{{tikzpicture}}[font=\fontsize{{{st['font_size_pt']}}}{{{st['font_size_pt']+2}}}\selectfont]")
    begin += "\n\\def\\edgecolor{EdgeColor}\n"
    begin += r"\tikzset{connection/.style={line width=0.7pt,draw=EdgeColor,opacity=0.95}}" + "\n"
    return [head, begin]


def spatial_size(shape, base, st):
    # Compress spatial scaling for readability. Exact numbers are printed;
    # rendered volume/thickness must never be interpreted as parameter count.
    return (st["feature_height"] * math.sqrt(shape[1] / base[1]),
            st["feature_depth"] * math.sqrt(shape[2] / base[2]))


def overview(m, st, out, rows, blocks):
    parts = preamble(st, out)
    x = 0.0
    last = None
    caps = []

    def add(name, width, h, d, color, gap=0.8, band=False):
        nonlocal x, last
        if last is not None:
            x += gap
        parts.append(box(name, x, width, h, d, color, st, band))
        if last is not None:
            parts.append(to_connection(last, name))
        middle = x + width * .1
        x += width * .2  # PlotNeuralNet's unmodified default scale is 0.2.
        last = name
        return middle

    inp = rows[0]["output"]
    mid = add("input", .8, st["input_height"], st["input_depth"], "InputColor")
    caps.append((mid, r"\textbf{MFCC}", dimensions(inp)))
    base = rows[1]["output"]
    mid = add("stem", st["stem_width"], st["feature_height"], st["feature_depth"], "StemColor", gap=1.25, band=True)
    caps.append((mid, r"\textbf{Stem}", rf"Conv ${pair(m['stem']['kernel'])}$\\$s=({m['stem']['stride'][0]},{m['stem']['stride'][1]})$"))
    parts.append(node(mid, 2.85, dimensions(base)))
    drop1 = add("drop1", .65, st["feature_height"], st["feature_depth"], "DropColor", gap=.65)
    parts.append(node(drop1, -2.7, rf"$p={m['dropout'][0]}$", "font=\\small"))
    for b in blocks:
        h, d = spatial_size(b["depthwise"], base, st)
        dw = add(f"dw{b['index']}", st["depthwise_width"], h, d, "DWColor", gap=st["block_gap_cm"], band=True)
        pw = add(f"pw{b['index']}", st["pointwise_width"], h, d, "PWColor", gap=st["within_block_gap_cm"], band=True)
        center = (dw + pw) / 2
        caps.append((center, rf"\textbf{{DS{b['index']}}}", rf"DW ${pair(b['kernel'])}$\\PW $1\times1$"))
        parts.append(node(center, 2.85, dimensions(b["output"])))
    h, d = spatial_size(blocks[-1]["output"], base, st)
    mid = add("drop2", .65, h, d, "DropColor", gap=.72)
    parts.append(node(mid, -2.7, rf"$p={m['dropout'][1]}$", "font=\\small"))
    mid = add("pool", 1.7, 7, 5, "PoolColor", gap=1.0)
    caps.append((mid, r"\textbf{AvgPool}", r"$1\times1$"))
    parts.append(node(mid, 1.65, dimensions((blocks[-1]["output"][0], 1, 1))))
    mid = add("fc", 2.6, 7, 4, "FCColor", gap=1.2)
    caps.append((mid, r"\textbf{FC}", rf"${blocks[-1]['output'][0]}\to {m['classes']}$"))
    mid = add("logits", .7, 11, 3, "InputColor", gap=1.1)
    caps.append((mid, r"\textbf{Logits}", str(m["classes"])))
    for middle, a, b in caps:
        # A font group must not span multiple TikZ alignment rows.
        parts.append(node(middle, -3.65, a + r"\\[-1pt]" + b, "font=\\small"))
    # Place explanatory notes and a compact legend on shared baselines.
    parts.append(node(x / 2, 4.25, rf"\textbf{{{tex_escape(m['name'])}}}: depthwise-separable keyword-spotting network", "font=\\large"))
    parts.append(node(x / 2, -4.55, r"Tensor labels: $C\times T\times F$ (batch omitted). Green bands: BN $\to$ ReLU. Dropout: training only.", "font=\\small"))
    parts.append(node(x / 2, -5.12, r"$\colorbox{DWColor}{\strut\phantom{aa}}$ depthwise\quad $\colorbox{PWColor}{\strut\phantom{aa}}$ pointwise\quad $\colorbox{BNColor}{\strut\phantom{aa}}$ BN + ReLU\quad $\colorbox{DropColor}{\strut\phantom{aa}}$ dropout", "font=\\small"))
    parts.append(node(x / 2, -5.68, r"Cuboid geometry is illustrative; tensor labels are exact.", "font=\\small"))
    # Flatten is an actual operation, but has no learnable tensor volume.
    parts.append(r"\node[font=\small,above=2pt] at ($(pool-east)!0.5!(fc-west)$) {Flatten};" + "\n")
    parts.append(to_end())
    return parts


def block_detail(m, st, out, blocks):
    parts = preamble(st, out)
    b = blocks[0]
    xs = [0, 3.7, 8.0, 11.8]
    names = ["blockinput", "blockdw", "blockpw", "blockoutput"]
    colors = ["InputColor", "DWColor", "PWColor", "InputColor"]
    widths = [1.5, 3.4, 4.5, 1.5]
    shapes = [b["input"], b["depthwise"], b["output"], b["output"]]
    for i, (name, x, color, width, shape) in enumerate(zip(names, xs, colors, widths, shapes)):
        h, d = spatial_size(shape, b["input"], st)
        parts.append(box(name, x, width, h, d, color, st, band=i in (1, 2)))
        if i:
            parts.append(to_connection(names[i-1], name))
        parts.append(node(x + width * .1, 2.8, dimensions(shape)))
    for x, width, title, sub in zip(xs, widths,
            ["Input", "Depthwise convolution", "Pointwise convolution", "Output"],
            ["", rf"${pair(b['kernel'])}$; groups $={b['groups']}$", rf"$1\times1$; ${b['input'][0]}\to {b['output'][0]}$ channels", ""]):
        parts.append(node(x + width * .1, -3.25, rf"\textbf{{{title}}}\\[-1pt]{{\small {sub}}}"))
    parts.append(node(6.1, 4.0, r"\textbf{Depthwise-separable block: spatial filtering followed by channel mixing}", "font=\\large"))
    parts.append(node(6.1, -4.35, rf"DW stride $=({b['stride'][0]},{b['stride'][1]})$, padding $=({b['padding'][0]},{b['padding'][1]})$. PW stride $=1$, padding $=0$.", "font=\\small"))
    parts.append(node(6.1, -4.95, r"Each green band represents BN $\to$ ReLU. No concatenation or residual connection.", "font=\\small"))
    parts.append(to_end())
    return parts


def generate(config, style, out):
    m = json.loads(config.read_text(encoding="utf-8"))
    st = json.loads(style.read_text(encoding="utf-8"))
    rows, blocks = inspect_model(m)
    out.mkdir(parents=True, exist_ok=True)
    for filename, content in [("dscnn_plotneuralnet.tex", overview(m, st, out, rows, blocks)),
                              ("ds_block_plotneuralnet.tex", block_detail(m, st, out, blocks))]:
        # Upstream to_generate prints its whole document. Keep terminal logs
        # short while using that real upstream writer without modification.
        with contextlib.redirect_stdout(io.StringIO()):
            to_generate(content, str(out / filename))
    manifest = {"name": m["name"], "model_sha256": hashlib.sha256(config.read_bytes()).hexdigest(),
                "plotneuralnet_commit": "e96bc852189c2089dd500527a0a01a5a36e8977e",
                "source_commit": m.get("source_commit"), "layers": rows, "blocks": blocks,
                "scope": "architecture visualization only; exact tensor labels; cuboids are illustrative"}
    (out / "shape_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return [out / "dscnn_plotneuralnet.tex", out / "ds_block_plotneuralnet.tex"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / "model.json")
    parser.add_argument("--style", type=Path, default=ROOT / "style.json")
    parser.add_argument("--out", type=Path, default=ROOT / "output" / "pdf")
    args = parser.parse_args()
    for filename in generate(args.config.resolve(), args.style.resolve(), args.out.resolve()):
        print(f"GENERATED={filename}")
