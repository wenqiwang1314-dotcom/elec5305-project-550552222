"""Meaningful shape/architecture checks, including a future width/depth edit."""
import copy
import json
import tempfile
from pathlib import Path
from draw_model import ROOT, inspect_model, generate


def check():
    model = json.loads((ROOT / "model.json").read_text())
    rows, blocks = inspect_model(model)
    assert rows[0]["output"] == (1, 49, 10)
    assert rows[1]["output"] == (64, 25, 5)
    assert len(blocks) == 4
    assert all(b["output"] == (64, 25, 5) and b["groups"] == 64 for b in blocks)
    assert rows[-1]["output"] == (12,)

    # A genuine model edit: three blocks, variable widths, downsampling, and
    # six classes. Groups must follow the previous width, not the new width.
    variant = copy.deepcopy(model)
    variant["stem"]["channels"] = 32
    variant["ds_blocks"] = variant["ds_blocks"][:3]
    for b in variant["ds_blocks"]:
        b["channels"] = 48
    variant["ds_blocks"][1]["stride"] = [2, 1]
    variant["classes"] = 6
    vr, vb = inspect_model(variant)
    assert vb[0]["groups"] == 32 and vb[0]["output"] == (48, 25, 5)
    assert vb[1]["groups"] == 48 and vb[1]["output"] == (48, 13, 5)
    assert vb[2]["output"] == (48, 13, 5) and vr[-1]["output"] == (6,)
    with tempfile.TemporaryDirectory(prefix="pnn_shape_test_") as temp:
        tmp = Path(temp)
        (tmp / "variant.json").write_text(json.dumps(variant))
        files = generate(tmp / "variant.json", ROOT / "style.json", tmp / "figures")
        text = files[0].read_text()
        assert "name=dw3" in text and "name=dw4" not in text
        assert "$48\\!\\times\\!13\\!\\times\\!5$" in text
        assert "$48\\to 6$" in text
    broken = copy.deepcopy(model)
    broken["stem"]["kernel"] = [999, 4]
    try:
        inspect_model(broken)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid spatial shape was silently accepted.")
    print("BASELINE_SHAPES_PASS=1\nMODIFIED_MODEL_GENERATION_PASS=1\nINVALID_SHAPE_REJECTION_PASS=1")


if __name__ == "__main__":
    check()
