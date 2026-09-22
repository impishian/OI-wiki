# OI Wiki Typst PDF 构建

本目录使用 Typst 0.15.0 将 464 篇导航页面和 2 篇明确附录排成一册 PDF。构建固定使用官方导出器提交 `a0743c869b166ccb4d3a42368f904a85384730a2`，并应用本地兼容补丁和书籍主题。

## 依赖

- Typst `0.15.0 (3ae52774)`；
- Python 3 及 PyYAML（用于页面清单和结构一致性验证）；
- Node.js、npm、Git。

PDF 直接由 Typst 生成，不依赖 Homebrew、ImageMagick 或 Poppler，也不执行 PNG 渲染或 Poppler 检查。

字体每类至少需要一种：正文为 LiSong Pro 或 New Computer Modern，标题为 LXGW WenKai GB Screen R 或 PingFang SC，代码为 DejaVu Sans Mono 或 Menlo，数学为 New Computer Modern Math 或 LiSong Pro。脚本搜索系统字体目录及 `tmp/pdfs/fonts`。

## 构建

在仓库根目录运行：

```bash
bash scripts/typst-pdf/build.sh
```

首次运行需联网克隆导出器、安装 npm 依赖，转换远程图片时也可能需要网络。完整构建耗时较长。中间文件和日志位于 `tmp/pdfs/`；转换使用临时 `source/` 副本，不会改写 `docs/` 原文。

如果网络不可用但本机已有固定提交的 exporter clone，可设置 `OI_WIKI_EXPORTER_URL` 为该本地 clone 的绝对路径；脚本会验证其固定提交后使用它。

最终文件为 `output/pdf/OI-Wiki-Typst-0.15.0.pdf`。若预检报告缺少命令或字体，请安装对应工具，或把所需字体放入 `tmp/pdfs/fonts`；`typst fonts` 可列出 Typst 实际识别的字体族。
