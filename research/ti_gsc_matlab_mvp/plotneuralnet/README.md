# TI DSCNN_NPU with PlotNeuralNet

实际使用 **HarisIqbal88/PlotNeuralNet** 的 Python 工具和原始 TikZ 三维图元生成，经过 LaTeX 编译。不是用其他绘图库仿画。

## 一键重新出图

在此目录打开 PowerShell：

```powershell
.\build.ps1
```

生成 `output/pdf/dscnn_plotneuralnet`（整体模型）和 `output/pdf/ds_block_plotneuralnet`（第一个 DS 块展开图），每个包含：

- `.pdf`：矢量原图，优先用于论文。
- `.svg`：矢量图，文字转路径以固定字体外观，可用 Inkscape/Illustrator 编辑图形。
- `.png`：600 dpi 图片，用于 Word/预览。
- `.tex`：可直接修改的 LaTeX/TikZ 源码。

`shape_manifest.json` 保存各层计算得到的实际尺寸。编译日志与 TeX 中间文件一同保留，以便排错。

## 修改模型

**只改 `model.json`**，然后运行 `build.ps1`。无需手动更新尺寸标签。

| 配置 | 修改内容 |
|---|---|
| `input.channels/time/features` | 输入 `[C,T,F]` |
| `stem.channels` | 首层输出通道数 |
| `stem.kernel/stride/padding` | 首层二维卷积参数 |
| `ds_blocks` | 增删列表元素改变 DS 块数量 |
| 每个块的 `channels` | 该块 PW 的输出通道数；DW 的 groups 自动取输入通道数 |
| 每个块的 `kernel/stride/padding` | DW 卷积参数；PW 固定 1×1、stride=1、padding=0 |
| `dropout` | 前后两处 dropout 概率 |
| `classes` | FC 输出类别数 |

示例：32 通道、3 个块模型，将 `stem.channels` 改为 32，把 `ds_blocks` 留 3 项，各项 `channels` 改为 32。另存配置可避免覆盖 TI 基线：

```powershell
.\build.ps1 --config model_variant.json --out output\variant
```

默认模板表示 `Conv+BN+ReLU -> Dropout -> (DW+BN+ReLU+PW+BN+ReLU)*n -> Dropout -> AvgPool -> Flatten -> FC`。如果增加 residual、Concat、attention 等**新拓扑**，需要扩展 `draw_model.py` 的 `inspect_model` 和 `overview`；仅修改名称不能代表新计算图。

## 修改排版

**只改 `style.json`**，包括字体大小、配色、块间距、块内 DW/PW 间距、三维块高/深/厚度和透明度。

三维形状经过视觉压缩，不用于表达参数量或严格按比例的张量体积；数字标签才是实际尺寸。每个绿色右侧薄带表示 `BatchNorm -> ReLU`，不是额外的卷积。所有 DS 块串联，各有独立参数。参考图中的残差、拼接和反卷积不属于此模型。

## 核心代码

- `draw_model.py`：参数读取、形状传播、PlotNeuralNet/TikZ 生成，含详细英文注释。
- `model.json`：独立的模型结构配置。
- `style.json`：独立的论文图样式配置。
- `build.py` / `build.ps1`：编译与输出流程。
- `test_generator.py`：基线、变体和非法形状检查。
- `vendor/PlotNeuralNet/pycore`、`vendor/PlotNeuralNet/layers`：未经修改的上游核心工具。
- `tools/bootstrap_tectonic.py`：固定版本编译器的校验与恢复。

仅生成 LaTeX，不编译：

```powershell
python draw_model.py --config model.json
python test_generator.py
```

## 换一台 Windows 电脑

1. 保留本目录结构，安装 Python 3。
2. 创建独立环境并安装渲染依赖：

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
python tools\bootstrap_tectonic.py
.\build.ps1
```

首次编译时 Tectonic 会联网下载 LaTeX 包并缓存；再次出图通常直接复用缓存。Tectonic 保存在项目内，不需要改系统 PATH 或注册表。Poppler 在 PATH 中时优先用于 PNG 渲染，否则使用 PyMuPDF；SVG 始终从 PDF 矢量内容转换。

Linux/macOS 可安装相应的 Tectonic 后，使用 `python build.py --engine /path/to/tectonic`。源代码不依赖 MATLAB。

## 学术来源与版本

- [PlotNeuralNet upstream](https://github.com/HarisIqbal88/PlotNeuralNet)，固定提交 `e96bc852189c2089dd500527a0a01a5a36e8977e`，MIT 许可证保存在 `vendor/PlotNeuralNet/LICENSE`。未修改其 Python/TikZ 文件。
- [TI 官方模型文档](https://software-dl.ti.com/C2000/esd/mcu_ai/user_guide/examples/google_speech_command.html#model-dscnn)。
- [TI 模型源码](https://github.com/TexasInstruments/tinyml-modelzoo/blob/b5fcd63e5d28fd7c9f1a7ea0f85b5778adcd9527/tinyml_modelzoo/models/audio.py#L8-L86)，固定提交 `b5fcd63e5d28fd7c9f1a7ea0f85b5778adcd9527`，类 `CNN_AUDIO_DSCNN`。
- Tectonic 0.17.0，官方发行包 SHA-256：`f61ce51f0b0ade1015b7de7ef368541c5424e9756ecbd0d7af97d6d48030845f`，已对照 GitHub 官方资产摘要。

此次是模型结构可视化，未训练模型或替换已有分类器。TI 源码中的输出是 logits；因此图中没有附加或虚构 Softmax 概率。

## English manuscript caption

**Architecture of the TI DSCNN_NPU keyword-spotting backbone.** A single-channel MFCC tensor with 49 time frames and 10 coefficients is processed by a strided convolutional stem and four independently parameterized depthwise-separable blocks. Each block applies a depthwise spatial convolution followed by a pointwise channel-mixing convolution. Green bands denote batch normalization and ReLU. Adaptive average pooling and a linear classifier produce 12 logits. Dropout is active only during training. Tensor labels exclude the batch dimension; cuboid geometry is illustrative. The architecture is redrawn from the cited Texas Instruments documentation and source using PlotNeuralNet.

**Depthwise-separable block.** Channel-wise spatial filtering is followed by learned 1×1 mixing across channels. Batch normalization and ReLU follow each convolution. Tensor dimensions and convolution settings correspond to the selected model configuration.
