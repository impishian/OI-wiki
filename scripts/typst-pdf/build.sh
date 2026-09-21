#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work_root="$repo_root/tmp/pdfs"
exporter_root="$work_root/OI-Wiki-export"
export_dir="$exporter_root/oi-wiki-export-typst"
source_root="$work_root/source"
build_python=python3
exporter_url="https://github.com/OI-wiki/OI-Wiki-export.git"
exporter_commit="a0743c869b166ccb4d3a42368f904a85384730a2"
expected_typst="typst 0.15.0 (3ae52774)"
output="$repo_root/output/pdf/OI-Wiki-Typst-0.15.0.pdf"

required_tools=(git node npm typst python3)
missing_tools=()
for tool in "${required_tools[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
if ((${#missing_tools[@]})); then
  printf 'missing required tools:' >&2
  printf ' %s' "${missing_tools[@]}" >&2
  printf '\n' >&2
  exit 1
fi

actual_typst="$(typst --version)"
if [[ "$actual_typst" != "$expected_typst" ]]; then
  printf 'expected %s, got %s\n' "$expected_typst" "$actual_typst" >&2
  exit 1
fi

mkdir -p "$work_root" "$repo_root/output/pdf"
"$build_python" -c 'import yaml' || {
  printf 'Python package PyYAML is required for navigation validation\n' >&2
  exit 1
}

"$build_python" "$repo_root/scripts/typst-pdf/check_nav.py" \
  --config "$repo_root/mkdocs.yml" --docs "$repo_root/docs" \
  --include edit-landing.md --include intro/docker-deploy.md \
  --output "$work_root/nav-manifest.json" --expect-count 466

if [[ ! -d "$exporter_root/.git" ]]; then
  git clone "$exporter_url" "$exporter_root"
fi
git -C "$exporter_root" fetch --depth 1 origin "$exporter_commit"
git -C "$exporter_root" checkout --detach "$exporter_commit"
git -C "$exporter_root" reset --hard "$exporter_commit"
git -C "$exporter_root" clean -ffd
git -C "$exporter_root" apply --check "$repo_root/scripts/typst-pdf/exporter-0.15.patch"
git -C "$exporter_root" apply "$repo_root/scripts/typst-pdf/exporter-0.15.patch"

for package in remark-snippet remark-typst oi-wiki-export-typst; do
  npm ci --prefix "$exporter_root/$package"
done
cp "$repo_root/scripts/typst-pdf/theme.typ" "$export_dir/theme.typ"
cp "$repo_root/scripts/typst-pdf/book.typ" "$export_dir/oi-wiki-export.typ"

# remark-snippet rewrites Markdown, so conversion uses a disposable source copy.
# Its mkdocs.yml keeps the original hierarchy and appends the two explicit pages.
"$build_python" - "$repo_root" "$source_root" <<'PY'
from pathlib import Path
import shutil
import sys

repo_root = Path(sys.argv[1]).resolve()
source_root = Path(sys.argv[2]).resolve()
if source_root.parent != (repo_root / "tmp" / "pdfs").resolve():
    raise SystemExit(f"refusing to replace unexpected source root: {source_root}")
if source_root.exists():
    shutil.rmtree(source_root)
source_root.mkdir(parents=True)
shutil.copytree(repo_root / "docs", source_root / "docs")

config = (repo_root / "mkdocs.yml").read_text(encoding="utf-8")
marker = "\ntheme:"
if config.count(marker) != 1:
    raise SystemExit("expected exactly one top-level theme section")
appendix = """
  - 附录:
    - 网页编辑入口说明: edit-landing.md
    - Docker 部署: intro/docker-deploy.md
"""
(source_root / "mkdocs.yml").write_text(
    config.replace(marker, appendix + marker), encoding="utf-8"
)
(source_root / "docs" / "edit-landing.md").write_text(
    """# 网页编辑入口说明

OI Wiki 网站中的“开始编辑”按钮依赖浏览器脚本和页面查询参数，无法在纸质版中运行。

如需参与维护，请先阅读[如何参与](./intro/htc.md)和[格式手册](./intro/format.md)，
然后访问 [OI Wiki 的 GitHub 仓库](https://github.com/OI-wiki/OI-wiki)，在对应文档页面发起修改。

提交内容时，请按项目约定填写作者信息和高质量的提交说明。
""",
    encoding="utf-8",
)
PY

font_paths=()
for candidate in /System/Library/Fonts /Library/Fonts /usr/local/share/fonts \
  /opt/homebrew/share/fonts "$work_root/fonts"; do
  [[ -d "$candidate" ]] && font_paths+=("$candidate")
done
font_args=()
for font_path in "${font_paths[@]}"; do
  font_args+=(--font-path "$font_path")
done
font_listing="$(typst fonts "${font_args[@]}")"

has_font_family() {
  local family
  for family in "$@"; do
    grep -Fqx "$family" <<<"$font_listing" && return 0
  done
  return 1
}

missing_font_categories=()
has_font_family "LiSong Pro" "New Computer Modern" || \
  missing_font_categories+=("body (LiSong Pro or New Computer Modern)")
has_font_family "LXGW WenKai GB Screen R" "PingFang SC" || \
  missing_font_categories+=("heading (LXGW WenKai GB Screen R or PingFang SC)")
has_font_family "DejaVu Sans Mono" "Menlo" || \
  missing_font_categories+=("code (DejaVu Sans Mono or Menlo)")
has_font_family "New Computer Modern Math" "LiSong Pro" || \
  missing_font_categories+=("math (New Computer Modern Math or LiSong Pro)")
if ((${#missing_font_categories[@]})); then
  printf 'missing required font categories:\n' >&2
  printf '  - %s\n' "${missing_font_categories[@]}" >&2
  exit 1
fi

(
  cd "$export_dir"
  node index.js "$source_root" 2>&1 | tee "$work_root/export.log"
)

"$build_python" - "$work_root/nav-manifest.json" \
  "$export_dir/converted-pages.json" <<'PY'
import json
from pathlib import Path
import sys

expected = [item["path"] for item in json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))]
actual = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
if len(actual) != 466:
    raise SystemExit(f"expected 466 converted pages, found {len(actual)}")
if actual != expected:
    missing = [page for page in expected if page not in actual]
    extra = [page for page in actual if page not in expected]
    raise SystemExit(f"conversion manifest mismatch; missing={missing}, extra={extra}")
print(f"converted {len(actual)} pages in navigation order")
PY

source_revision="$(git -C "$repo_root" rev-parse --short=12 HEAD)"
build_date="$(date +%F)"
(
  cd "$export_dir"
  typst compile "${font_args[@]}" \
    --input "source-revision=$source_revision" \
    --input "build-date=$build_date" --input "typst-version=0.15.0" \
    oi-wiki-export.typ "$output" 2>&1 | tee "$work_root/typst.log"
)
printf 'built %s\n' "$output"
