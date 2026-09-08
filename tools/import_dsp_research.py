"""Import the standalone, verified MATLAB study using an explicit allowlist.

Usage: python tools/import_dsp_research.py --source /path/to/ti_gsc_matlab_mvp
The original dataset and project are read only. Local runtimes, Git metadata,
MATLAB figure caches, execution logs, and private source paths are excluded.
Run the release verifier and review the diff before publishing an update.
"""
import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "research" / "ti_gsc_matlab_mvp"
FIGURES = ROOT / "docs" / "assets" / "research"


def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    source = parser.parse_args().source.resolve()
    assert source != DEST.resolve(), "Use the independent original study as source."
    for name in ("run_ti_gsc_mvp.m", "run_ti_gsc_single_audio.m", "validate_refactor.m"):
        copy(source / name, DEST / name)
    for item in (source / "+tigsc").glob("*.m"):
        copy(item, DEST / "+tigsc" / item.name)
    for name in ("run_ti_gsc_mvp_original.m", "legacy_mfcc.m", "baseline.mat"):
        copy(source / "reference" / name, DEST / "reference" / name)
    for name in ("yes.wav", "LICENSE", "dataset_README.md"):
        copy(source / "examples" / name, DEST / "examples" / name)
    attribution = (source / "examples" / "README.md").read_text(encoding="utf-8")
    attribution = "\n".join(line for line in attribution.splitlines()
                            if not line.startswith("- Source directory:")) + "\n"
    (DEST / "examples" / "README.md").write_text(attribution, encoding="utf-8")
    trace = source / "output" / "real_yes_walkthrough"
    for item in trace.iterdir():
        if item.suffix in (".png", ".pdf", ".svg"):
            copy(item, FIGURES / item.name)
        elif item.suffix in (".csv", ".bin"):
            copy(item, DEST / "evidence" / "real_yes_walkthrough" / item.name)
    contract = json.loads((trace / "feature_contract.json").read_text(encoding="utf-8"))
    contract["audio_source"] = "examples/yes.wav"
    (DEST / "evidence" / "real_yes_walkthrough" / "feature_contract.json").write_text(
        json.dumps(contract, indent=2) + "\n", encoding="utf-8")
    for name in ("validation_results.txt", "regression_comparison.csv"):
        copy(source / "output" / "validation" / name, DEST / "evidence" / "validation" / name)
    plot = source / "plotneuralnet"
    for name in ("draw_model.py", "build.py", "build.ps1", "test_generator.py",
                 "model.json", "style.json", "requirements.txt", "README.md", "VENDOR_LOCK.json",
                 "tools/bootstrap_tectonic.py", "tools/tectonic_provenance.json"):
        copy(plot / name, DEST / "plotneuralnet" / name)
    vendor = Path("vendor/PlotNeuralNet")
    for name in ("LICENSE", "README.md"):
        copy(plot / vendor / name, DEST / "plotneuralnet" / vendor / name)
    for directory, extension in (("pycore", ".py"), ("layers", ".sty"), ("layers", ".tex")):
        for item in (plot / vendor / directory).glob("*" + extension):
            copy(item, DEST / "plotneuralnet" / vendor / directory / item.name)
    for stem in ("dscnn_plotneuralnet", "ds_block_plotneuralnet"):
        for extension in (".pdf", ".png", ".svg"):
            copy(plot / "output" / "pdf" / (stem + extension), FIGURES / (stem + extension))
    copy(plot / "output" / "pdf" / "shape_manifest.json",
         DEST / "evidence" / "shape_manifest.json")
    print("RESEARCH_IMPORT_PASS=1")


if __name__ == "__main__":
    main()
