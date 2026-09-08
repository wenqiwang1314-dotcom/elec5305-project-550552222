"""One-command generation, LaTeX compilation and vector/raster exports.

Compilation uses the project's portable Tectonic, or an explicit --engine.
Poppler creates 600-dpi PNG and PyMuPDF exports vector SVG directly from the
compiled PDF. No raster intermediate enters the vector figure. Supply
--poppler-dir when Poppler is not on PATH; PyMuPDF is the raster fallback.
"""
import argparse
import json
import shutil
import subprocess
from pathlib import Path
from draw_model import ROOT, generate


def command(args, logfile):
    run = subprocess.run(list(map(str, args)), cwd=ROOT, text=True,
                         encoding="utf-8", errors="replace", capture_output=True)
    logfile.write_text(run.stdout + run.stderr, encoding="utf-8")
    if run.returncode:
        raise RuntimeError(f"Command failed ({run.returncode}); see {logfile}\n" + run.stderr[-1800:])


def find_binary(name, explicit=None):
    result = str(explicit / name) if explicit else shutil.which(name)
    if not result or not Path(result).is_file():
        raise FileNotFoundError(f"Missing {name}; install Poppler or provide --poppler-dir.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / "model.json")
    parser.add_argument("--style", type=Path, default=ROOT / "style.json")
    parser.add_argument("--out", type=Path, default=ROOT / "output" / "pdf")
    parser.add_argument("--engine", type=Path, default=ROOT / "tools" / "tectonic" / "tectonic.exe")
    parser.add_argument("--poppler-dir", type=Path)
    parser.add_argument("--dpi", type=int, default=600)
    parser.add_argument("--generate-only", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    generated = generate(args.config.resolve(), args.style.resolve(), out)
    if args.generate_only:
        print("LATEX_GENERATION_PASS=1")
        return
    if not args.engine.is_file():
        raise FileNotFoundError("Tectonic not found. Run tools/bootstrap_tectonic.py or provide --engine.")
    ext = ".exe" if __import__("os").name == "nt" else ""
    import pymupdf
    try:
        ppm = find_binary("pdftoppm" + ext, args.poppler_dir)
    except FileNotFoundError:
        ppm = None
    for tex in generated:
        command([args.engine.resolve(), "--keep-logs", "--keep-intermediates", "--outdir", out, tex],
                tex.with_suffix(".build.log"))
        pdf = tex.with_suffix(".pdf")
        assert pdf.read_bytes().startswith(b"%PDF-"), "Expected a compiled PDF."
        with pymupdf.open(pdf) as doc:
            assert len(doc) == 1, "Each diagram must be a standalone page."
            if ppm:
                command([ppm, "-png", "-singlefile", "-r", str(args.dpi), pdf, tex.with_suffix("")],
                        tex.with_suffix(".render.log"))
            else:
                doc[0].get_pixmap(dpi=args.dpi).save(tex.with_suffix(".png"))
            tex.with_suffix(".svg").write_text(doc[0].get_svg_image(text_as_path=True), encoding="utf-8")
        print(f"FIGURE_PASS={pdf}")
    print("PLOTNEURALNET_BUILD_PASS=1")


if __name__ == "__main__":
    main()
