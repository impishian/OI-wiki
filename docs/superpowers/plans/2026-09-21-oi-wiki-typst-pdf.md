# OI Wiki Typst 0.15.0 PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build all 466 original Markdown documents (464 `mkdocs.yml` pages plus two explicit appendices) into one polished, verified PDF at `output/pdf/OI-Wiki-Typst-0.15.0.pdf` with Typst 0.15.0.

**Architecture:** Pin OI Wiki's official Typst exporter at its tested 0.15.0 upgrade commit, apply a small local compatibility/behavior patch, and replace only the top-level book template with a repository-owned print template. A shell entry point owns dependency/font setup and the full build; small Python programs independently validate navigation coverage and the finished PDF so conversion failures cannot silently produce an incomplete book.

**Tech Stack:** Typst 0.15.0, Node.js 20+, OI-Wiki-export/remark-typst, Bash, Python 3.10+, PyYAML, pypdf, pdfplumber, Poppler (`pdfinfo`, `pdftotext`, `pdftoppm`, `pdffonts`), ImageMagick.

---

## File map

- `scripts/typst-pdf/build.sh`: reproducible end-to-end build entry point; pins exporter commit, prepares fonts, converts Markdown, compiles Typst, and invokes verification.
- `scripts/typst-pdf/check_nav.py`: extracts the ordered Markdown list from `mkdocs.yml`, appends explicitly requested auxiliary pages, rejects missing/duplicate pages, and writes the build manifest.
- `scripts/typst-pdf/verify_pdf.py`: validates the final PDF's structure, metadata, page text, title coverage, links, and fonts.
- `scripts/typst-pdf/exporter-0.15.patch`: repository-owned patch over upstream commit `a0743c869b166ccb4d3a42368f904a85384730a2`; removes QR appendices, makes missing images fatal, and emits a conversion manifest.
- `scripts/typst-pdf/book.typ`: repository-owned A4 book shell with cover, metadata page, contents, section styling, page headers/footers, and final colophon.
- `scripts/typst-pdf/theme.typ`: focused reusable styles for typography, code, tables, images, quotations, links, and admonitions.
- `scripts/typst-pdf/requirements.txt`: pinned Python dependencies for manifest tests and PDF verification.
- `scripts/typst-pdf/README.md`: dependencies, one-command build, outputs, and troubleshooting.
- `test/typst_pdf/test_check_nav.py`: navigation manifest unit tests.
- `test/typst_pdf/test_verify_pdf.py`: verifier unit tests using minimal generated PDF fixtures.
- `test/typst_pdf/fixtures/mkdocs-valid.yml`: minimal nested navigation fixture.
- `test/typst_pdf/fixtures/docs/intro.md`: first navigation fixture page.
- `test/typst_pdf/fixtures/docs/algorithm.md`: second navigation fixture page.
- `.gitignore`: ignores `tmp/pdfs/` and generated PDF artifacts while keeping scripts/templates tracked.
- `.github/workflows/build-pdf-typst.yml`: upgrades CI's requested Typst version from 0.13.1 to 0.15.0 and calls the repository build entry point.
- `output/pdf/OI-Wiki-Typst-0.15.0.pdf`: final generated deliverable; do not commit this large binary unless the user explicitly asks.

### Task 1: Add navigation-manifest validation

**Files:**
- Create: `scripts/typst-pdf/check_nav.py`
- Create: `test/typst_pdf/test_check_nav.py`
- Create: `test/typst_pdf/fixtures/mkdocs-valid.yml`
- Create: `test/typst_pdf/fixtures/docs/intro.md`
- Create: `test/typst_pdf/fixtures/docs/algorithm.md`
- Create: `scripts/typst-pdf/requirements.txt`

- [ ] **Step 1: Create a nested navigation fixture**

```yaml
# test/typst_pdf/fixtures/mkdocs-valid.yml
nav:
  - 简介:
      - 入门: intro.md
  - 算法:
      - 基础: algorithm.md
```

Create `intro.md` with `# 入门` and `algorithm.md` with `# 基础`.

- [ ] **Step 2: Write failing tests for order, duplicate detection, and missing files**

```python
# test/typst_pdf/test_check_nav.py
from pathlib import Path
import shutil
import sys

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "typst-pdf"))
from check_nav import build_manifest


def test_build_manifest_preserves_nested_order():
    fixture = ROOT / "test" / "typst_pdf" / "fixtures"
    result = build_manifest(fixture / "mkdocs-valid.yml", fixture / "docs")
    assert [item["path"] for item in result] == ["intro.md", "algorithm.md"]
    assert [item["title"] for item in result] == ["入门", "基础"]


def test_build_manifest_rejects_duplicate_pages(tmp_path):
    fixture = ROOT / "test" / "typst_pdf" / "fixtures"
    shutil.copytree(fixture / "docs", tmp_path / "docs")
    config = tmp_path / "mkdocs.yml"
    config.write_text("nav:\n  - A: intro.md\n  - B: intro.md\n", encoding="utf-8")
    with pytest.raises(ValueError, match="duplicate navigation page: intro.md"):
        build_manifest(config, tmp_path / "docs")


def test_build_manifest_rejects_missing_pages(tmp_path):
    (tmp_path / "docs").mkdir()
    config = tmp_path / "mkdocs.yml"
    config.write_text("nav:\n  - Missing: missing.md\n", encoding="utf-8")
    with pytest.raises(FileNotFoundError, match="missing.md"):
        build_manifest(config, tmp_path / "docs")
```

- [ ] **Step 3: Create the isolated Python test environment**

```text
# scripts/typst-pdf/requirements.txt
pdfplumber==0.11.7
pypdf==6.0.0
pytest==8.4.2
PyYAML==6.0.2
```

Run:

```bash
rtk python3 -m venv tmp/pdfs/venv
rtk tmp/pdfs/venv/bin/python -m pip install -r scripts/typst-pdf/requirements.txt
```

Expected: dependency installation exits 0.

- [ ] **Step 4: Run the tests and confirm the module is absent**

Run: `rtk tmp/pdfs/venv/bin/python -m pytest test/typst_pdf/test_check_nav.py -q`

Expected: FAIL during collection with `ModuleNotFoundError: No module named 'check_nav'`.

- [ ] **Step 5: Implement the manifest extractor and CLI**

```python
# scripts/typst-pdf/check_nav.py
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml


def _walk(nodes: list[Any]):
    for node in nodes:
        if isinstance(node, str):
            yield Path(node).stem, node
        elif isinstance(node, dict):
            for title, value in node.items():
                if isinstance(value, str):
                    yield str(title), value
                elif isinstance(value, list):
                    yield from _walk(value)
                else:
                    raise TypeError(f"unsupported nav value for {title!r}: {type(value).__name__}")
        else:
            raise TypeError(f"unsupported nav node: {type(node).__name__}")


def build_manifest(config_path: Path, docs_dir: Path) -> list[dict[str, str]]:
    # BaseLoader preserves the navigation strings while safely tolerating the
    # !!python/name tags used elsewhere in the real mkdocs.yml.
    config = yaml.load(config_path.read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
    nav = config.get("nav")
    if not isinstance(nav, list):
        raise ValueError("mkdocs.yml must contain a list-valued nav")

    result: list[dict[str, str]] = []
    seen: set[str] = set()
    for title, relative in _walk(nav):
        if not relative.endswith(".md"):
            raise ValueError(f"navigation page is not Markdown: {relative}")
        if relative in seen:
            raise ValueError(f"duplicate navigation page: {relative}")
        source = docs_dir / relative
        if not source.is_file():
            raise FileNotFoundError(f"navigation page does not exist: {relative}")
        seen.add(relative)
        result.append({"title": title, "path": relative})
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--docs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expect-count", type=int)
    args = parser.parse_args()
    manifest = build_manifest(args.config, args.docs)
    if args.expect_count is not None and len(manifest) != args.expect_count:
        raise SystemExit(f"expected {args.expect_count} pages, found {len(manifest)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"validated {len(manifest)} navigation pages")


if __name__ == "__main__":
    main()
```

- [ ] **Step 6: Run unit and real-repository checks**

Run:

```bash
rtk tmp/pdfs/venv/bin/python -m pytest test/typst_pdf/test_check_nav.py -q
rtk tmp/pdfs/venv/bin/python scripts/typst-pdf/check_nav.py --config mkdocs.yml --docs docs --include edit-landing.md --include intro/docker-deploy.md --output tmp/pdfs/nav-manifest.json --expect-count 466
```

Expected: `3 passed` and `validated 466 navigation pages` with the two explicit includes.

- [ ] **Step 7: Commit the manifest validator and dependency pins**

```bash
rtk git add scripts/typst-pdf/check_nav.py scripts/typst-pdf/requirements.txt test/typst_pdf
rtk git commit -m "test: validate Typst PDF navigation manifest"
```

### Task 2: Pin and patch the official Typst 0.15 exporter

**Files:**
- Create: `scripts/typst-pdf/exporter-0.15.patch`
- Create: `scripts/typst-pdf/build.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Write the build-script preflight and pinned exporter checkout**

Create `scripts/typst-pdf/build.sh` with this initial content:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work_root="$repo_root/tmp/pdfs"
exporter_root="$work_root/OI-Wiki-export"
exporter_url="https://github.com/OI-wiki/OI-Wiki-export.git"
exporter_commit="a0743c869b166ccb4d3a42368f904a85384730a2"
expected_typst="typst 0.15.0 (3ae52774)"

actual_typst="$(typst --version)"
if [[ "$actual_typst" != "$expected_typst" ]]; then
  printf 'expected %s, got %s\n' "$expected_typst" "$actual_typst" >&2
  exit 1
fi

mkdir -p "$work_root" "$repo_root/output/pdf"
python3 "$repo_root/scripts/typst-pdf/check_nav.py" \
  --config "$repo_root/mkdocs.yml" \
  --docs "$repo_root/docs" \
  --include edit-landing.md \
  --include intro/docker-deploy.md \
  --output "$work_root/nav-manifest.json" \
  --expect-count 466

if [[ ! -d "$exporter_root/.git" ]]; then
  git clone "$exporter_url" "$exporter_root"
fi
git -C "$exporter_root" fetch origin "$exporter_commit"
git -C "$exporter_root" checkout --detach "$exporter_commit"
git -C "$exporter_root" reset --hard "$exporter_commit"
git -C "$exporter_root" clean -ffd
git -C "$exporter_root" apply --check "$repo_root/scripts/typst-pdf/exporter-0.15.patch"
git -C "$exporter_root" apply "$repo_root/scripts/typst-pdf/exporter-0.15.patch"
```

- [ ] **Step 2: Add a patch that changes exporter behavior without forking it**

In a clean checkout of upstream commit `a0743c869b166ccb4d3a42368f904a85384730a2`, edit `remark-typst/lib/compiler.js` as follows:

1. Remove `arrayLinks`, `linkIndex`, `hasFootnotes`, and `parsingPlain`. Remove the post-parse conditional that starts with `if (linkIndex > 0)` and appends the `#links-grid` external-reference section.
2. Replace the external-link branch in `makeLink` with this complete branch:

```javascript
      } else {
        const location = url.replace(/\\/g, '\\\\')
        const children = all(node, parse).join('')
        return '#link("{0}")[{1}]'.format(location, children)
      }
```

3. Replace the image-processing catch block with:

```javascript
      } catch (e) {
        throw new Error(
          'Error occurred when processing image file "{0}": {1}'.format(uri, e.message),
        )
      }
```

In `oi-wiki-export-typst/index.js`, add this state immediately after `labelHistory`:

```javascript
const convertedPages = []
const convertedPageSet = new Set()
```

Change the `convertMarkdown` signature to `async function convertMarkdown(filename, depth, title, sourcePath)`. Replace its callback-form unified processor invocation with this awaited form, including the manifest bookkeeping:

```javascript
    const file = await unified()
      .use(remarkParse)
      .use(remarkMath)
      .use(remarkGfm)
      .use(remarkDetails)
      .use(remarkTabbed)
      .use(remarkTypst, {
        prefix: filename.replace(PREFIX_REGEX, '').replace(/md$/, ''),
        depth: depth,
        current: filename,
        root: join(oiwikiRoot, 'docs'),
        nested: false,
        forceLinebreak: false,
        path: filename.replace(/\.md$/, '/'),
        title: title,
      })
      .process(await read(filename))

    file.dirname = 'typ'
    file.stem = filename.replace(PREFIX_REGEX, '')
    file.extname = '.typ'
    writeSync(file)

    if (convertedPageSet.has(sourcePath)) {
      throw new Error('Page converted twice: ' + sourcePath)
    }
    convertedPageSet.add(sourcePath)
    convertedPages.push(sourcePath)
```

Change the call site to:

```javascript
        await convertMarkdown(
          join(oiwikiRoot, 'docs', object[key]),
          depth + 1,
          key,
          object[key],
        )
```

Immediately after writing `includes.typ`, write the manifest:

```javascript
  await fs.writeFile(
    'converted-pages.json',
    JSON.stringify(convertedPages, null, 2) + '\n',
  )
```

Generate the tracked patch from the clean upstream checkout:

```bash
rtk git -C /private/tmp/oi-wiki-export-plan-20260921 diff \
  --output="$PWD/scripts/typst-pdf/exporter-0.15.patch" -- \
  remark-typst/lib/compiler.js oi-wiki-export-typst/index.js
```

- [ ] **Step 3: Add ignored build/output paths**

Append to `.gitignore`:

```gitignore
/tmp/pdfs/
/output/pdf/*.pdf
```

- [ ] **Step 4: Verify the patch applies cleanly to the pinned commit**

Run:

```bash
rtk bash -n scripts/typst-pdf/build.sh
rtk git -C /private/tmp/oi-wiki-export-plan-20260921 checkout --detach a0743c869b166ccb4d3a42368f904a85384730a2
rtk git -C /private/tmp/oi-wiki-export-plan-20260921 apply --check "$PWD/scripts/typst-pdf/exporter-0.15.patch"
```

Expected: both commands exit 0 with no output.

- [ ] **Step 5: Commit the pinned exporter integration**

```bash
rtk git add .gitignore scripts/typst-pdf/build.sh scripts/typst-pdf/exporter-0.15.patch
rtk git commit -m "build: pin Typst 0.15 OI Wiki exporter"
```

### Task 3: Create the book theme and compile a fixture

**Files:**
- Create: `scripts/typst-pdf/theme.typ`
- Create: `scripts/typst-pdf/book.typ`
- Create: `test/typst_pdf/fixtures/theme-smoke.typ`

- [ ] **Step 1: Create a smoke document that exercises every custom component**

````typst
// test/typst_pdf/fixtures/theme-smoke.typ
#import "../../../scripts/typst-pdf/theme.typ": *
#show: book-theme

= 测试分部
== 代表文章

正文包含 #link("https://oi-wiki.org")[外部链接]、`inline_code` 与公式 $sum_(i=1)^n i$。

#admonition(kind: "tip", title: [技巧])[提示框内容。]

```cpp
int main() { return 0; }
```

#table(columns: 2, [算法], [复杂度], [二分], [$O(log n)$])

#figure(rect(width: 45mm, height: 18mm, fill: rgb("d9f2f2")), caption: [测试图片])
````

- [ ] **Step 2: Run the smoke compile and observe the missing import**

Run: `rtk typst compile --root . test/typst_pdf/fixtures/theme-smoke.typ tmp/pdfs/theme-smoke.pdf`

Expected: FAIL because `scripts/typst-pdf/theme.typ` does not exist.

- [ ] **Step 3: Implement the reusable A4 theme**

Create `scripts/typst-pdf/theme.typ` with exported `book-theme`, `admonition`, `page-header`, `img-auto`, `sourcecode`, `blockquote`, `authors`, `kbd`, `svg-math`, `tablex-custom`, `tabbed`, `horizontalrule`, and link styling functions expected by upstream generated content. Use these fixed design tokens:

```typst
#let navy = rgb("17324d")
#let cyan = rgb("168c96")
#let ink = rgb("202832")
#let muted = rgb("667381")
#let paper = rgb("ffffff")
#let panel = rgb("f3f7f8")
#let rule = rgb("d3dde2")
#let body-font = ("Noto Serif CJK SC", "Songti SC", "New Computer Modern")
#let heading-font = ("LXGW WenKai", "Noto Sans CJK SC", "PingFang SC")
#let code-font = ("DejaVu Sans Mono", "Noto Sans Mono CJK SC", "Menlo")
#let math-font = ("New Computer Modern Math", "Noto Serif CJK SC")

#let book-theme(body) = {
  set document(title: "OI Wiki", author: "OI Wiki Team")
  set page(
    paper: "a4",
    margin: (inside: 24mm, outside: 19mm, top: 21mm, bottom: 22mm),
    binding: left,
    fill: paper,
  )
  set text(size: 10pt, fill: ink, font: body-font, lang: "zh", region: "cn")
  set par(justify: true, leading: 0.72em, linebreaks: "optimized")
  set block(spacing: 0.78em)
  show heading: set text(font: heading-font, fill: navy, weight: 600)
  show link: set text(fill: cyan)
  show raw.where(block: false): it => box(fill: panel, inset: (x: 3pt, y: 1pt), radius: 2pt, it)
  body
}
```

Implement `sourcecode` with `raw` block styling, `breakable: true`, a 0.6pt `rule` border, 6pt inset, 3pt radius, 8.6pt type, and no forced fixed height. Implement admonitions with a left border plus a visible title so grayscale output retains meaning. Implement `img-auto` with `image(src, alt: alt, width: 100%, fit: "contain")` inside a centered block. Implement `tablex-custom` with repeating header-compatible `table`, 8.5pt text, subtle horizontal rules, and no heavy full-grid border.

- [ ] **Step 4: Implement the top-level book shell**

Create `scripts/typst-pdf/book.typ` that imports upstream `oi-wiki.typ` and local `theme.typ`, then provides:

```typst
#import "theme.typ": *
#import "oi-wiki.typ": *
#show: book-theme

#let source-revision = sys.inputs.at("source-revision", default: "unknown")
#let build-date = sys.inputs.at("build-date", default: "unknown")
#let typst-version = sys.inputs.at("typst-version", default: "0.15.0")

#set page(header: none, footer: none, fill: rgb("f3f7f8"))
#align(center + horizon)[
  #text(13pt, fill: cyan, tracking: 1.4pt)[COMPETITIVE PROGRAMMING HANDBOOK]
  #v(14mm)
  #text(36pt, font: heading-font, fill: navy, weight: 700)[OI Wiki]
  #v(4mm)
  #text(15pt, fill: muted)[信息学竞赛知识整合站点 · 完整典藏版]
  #v(38mm)
  #line(length: 45mm, stroke: 1.5pt + cyan)
  #v(8mm)
  #text(11pt, fill: muted)[OI Wiki Team · #build-date]
]

#pagebreak(to: "even")
#set page(fill: white)
= 版本与许可
#table(
  columns: (34mm, 1fr),
  stroke: none,
  inset: (x: 0pt, y: 3pt),
  [源版本], [#source-revision],
  [排版系统], [Typst #typst-version],
  [生成日期], [#build-date],
  [项目网站], [#link("https://oi-wiki.org")],
)

#pagebreak(to: "odd")
#outline(title: [目录], depth: 3, indent: 1.4em)
#pagebreak(to: "odd")
#set page(header: page-header, footer: context align(center, counter(page).display("1")))
#counter(page).update(1)
#include "includes.typ"

#pagebreak(to: "odd")
#set page(header: none, footer: none, fill: rgb("17324d"))
#align(center + horizon, text(13pt, fill: white)[https://oi-wiki.org])
```

Add show rules for level-1 section openers, level-2 article headings, orphan control, footnotes, references, lists, tables, figures, blockquotes, and raw blocks. Preserve the function names expected by generated Typst files.

- [ ] **Step 5: Compile and render the smoke fixture**

Run:

```bash
rtk typst compile --root . test/typst_pdf/fixtures/theme-smoke.typ tmp/pdfs/theme-smoke.pdf
rtk pdftoppm -png -f 1 -l 1 -r 144 tmp/pdfs/theme-smoke.pdf tmp/pdfs/theme-smoke
```

Expected: a one-page PDF and `tmp/pdfs/theme-smoke-1.png`; no Typst warnings about missing fonts, overflow, or unknown functions.

- [ ] **Step 6: Visually inspect the PNG**

Inspect `tmp/pdfs/theme-smoke-1.png`. Confirm readable Chinese, distinct heading hierarchy, uncut code, aligned formula, restrained table rules, and a grayscale-safe admonition. Adjust only `theme.typ` until the fixture is clean.

- [ ] **Step 7: Commit the book template**

```bash
rtk git add scripts/typst-pdf/theme.typ scripts/typst-pdf/book.typ test/typst_pdf/fixtures
rtk git commit -m "feat: add OI Wiki Typst book theme"
```

### Task 4: Complete dependency, font, and compilation orchestration

**Files:**
- Modify: `scripts/typst-pdf/build.sh`
- Create: `scripts/typst-pdf/README.md`

- [ ] **Step 1: Add deterministic dependency setup**

Append to `build.sh`:

```bash
venv_root="$work_root/venv"
if [[ ! -x "$venv_root/bin/python" ]]; then
  python3 -m venv "$venv_root"
fi
"$venv_root/bin/python" -m pip install --disable-pip-version-check \
  -r "$repo_root/scripts/typst-pdf/requirements.txt"

for package in remark-snippet remark-typst oi-wiki-export-typst; do
  npm ci --prefix "$exporter_root/$package"
done

export_dir="$exporter_root/oi-wiki-export-typst"
cp "$repo_root/scripts/typst-pdf/theme.typ" "$export_dir/theme.typ"
cp "$repo_root/scripts/typst-pdf/book.typ" "$export_dir/oi-wiki-export.typ"
```

Replace every build-script invocation of `python3 check_nav.py` or `python3 verify_pdf.py` with `"$venv_root/bin/python"` followed by the same script and arguments.

Use `command -v` preflights for `git`, `node`, `npm`, `typst`, `convert`, `pdfinfo`, `pdftotext`, `pdftoppm`, `pdffonts`, and `python3`. Print all missing tools in one error and exit 1.

- [ ] **Step 2: Add explicit font-path discovery**

Define a `font_paths` array containing existing directories only, from:

```bash
/System/Library/Fonts
/Library/Fonts
/usr/local/share/fonts
/opt/homebrew/share/fonts
$work_root/fonts
```

Build repeated `--font-path` arguments from this array. Run `typst fonts` with those arguments and require the family names `Noto Serif CJK SC` or `Songti SC`, `LXGW WenKai` or `Noto Sans CJK SC`, and `DejaVu Sans Mono` or `Menlo`. Exit with a message listing the missing family category if any category has no match.

- [ ] **Step 3: Add conversion, manifest comparison, and compilation**

Append:

```bash
(
  cd "$export_dir"
  node index.js "$repo_root" 2>&1 | tee "$work_root/export.log"
)

python3 - "$work_root/nav-manifest.json" "$export_dir/converted-pages.json" <<'PY'
import json, sys
expected = [item["path"] for item in json.load(open(sys.argv[1], encoding="utf-8"))]
actual = json.load(open(sys.argv[2], encoding="utf-8"))
if actual != expected:
    missing = [p for p in expected if p not in actual]
    extra = [p for p in actual if p not in expected]
    raise SystemExit(f"conversion manifest mismatch; missing={missing}, extra={extra}")
print(f"converted {len(actual)} pages in navigation order")
PY

source_revision="$(git -C "$repo_root" rev-parse --short=12 HEAD)"
build_date="$(date +%F)"
output="$repo_root/output/pdf/OI-Wiki-Typst-0.15.0.pdf"

(
  cd "$export_dir"
  typst compile oi-wiki-export.typ "$output" \
    "${font_args[@]}" \
    --input "source-revision=$source_revision" \
    --input "build-date=$build_date" \
    --input "typst-version=0.15.0" \
    2>&1 | tee "$work_root/typst.log"
)

python3 "$repo_root/scripts/typst-pdf/verify_pdf.py" \
  --pdf "$output" \
  --manifest "$work_root/nav-manifest.json" \
  --source-revision "$source_revision" \
  --typst-version 0.15.0
```

Ensure `pipefail` remains active so `tee` cannot hide Node or Typst failures.

- [ ] **Step 4: Document the exact build command**

Create `scripts/typst-pdf/README.md` with prerequisites, pinned exporter SHA, the one-command build below, temporary/output paths, expected long runtime, network needs for npm/Typst packages/remote images, and remediation for missing fonts:

```bash
rtk bash scripts/typst-pdf/build.sh
```

- [ ] **Step 5: Check the script without starting the expensive full build**

Run:

```bash
rtk bash -n scripts/typst-pdf/build.sh
rtk shellcheck scripts/typst-pdf/build.sh
```

Expected: both exit 0. If `shellcheck` is unavailable, install it or explicitly run the repository's available shell linter; do not skip syntax checking.

- [ ] **Step 6: Commit the build entry point**

```bash
rtk git add scripts/typst-pdf/build.sh scripts/typst-pdf/README.md
rtk git commit -m "build: orchestrate complete Typst PDF export"
```

### Task 5: Add structural PDF verification

**Files:**
- Create: `scripts/typst-pdf/verify_pdf.py`
- Create: `test/typst_pdf/test_verify_pdf.py`

- [ ] **Step 1: Write tests for metadata, text markers, links, and title coverage**

In `test_verify_pdf.py`, create a two-page PDF fixture with `pypdf.PdfWriter`, metadata fields `/Title`, `/Subject`, `/Keywords`, one URI link, and text pages generated by Typst from a temporary `.typ` source. Assert:

```python
report = verify_pdf(
    pdf_path=fixture_pdf,
    manifest=[{"title": "入门", "path": "intro.md"}],
    source_revision="abc123",
    typst_version="0.15.0",
)
assert report.page_count == 2
assert report.title_coverage == 1.0
assert report.uri_links == 1
assert report.missing_titles == []
```

Add negative tests for a wrong title, missing revision marker, a blank page not marked as an intentional chapter verso, and a manifest title absent from extracted text.

- [ ] **Step 2: Run tests and verify the module is absent**

Run: `rtk tmp/pdfs/venv/bin/python -m pytest test/typst_pdf/test_verify_pdf.py -q`

Expected: FAIL with `ModuleNotFoundError: No module named 'verify_pdf'`.

- [ ] **Step 3: Implement `verify_pdf.py`**

Define:

```python
@dataclass(frozen=True)
class VerificationReport:
    page_count: int
    file_size: int
    title_coverage: float
    missing_titles: list[str]
    uri_links: int
    embedded_fonts: list[str]
```

Implement `verify_pdf(pdf_path, manifest, source_revision, typst_version)` to:

- reopen the PDF with both `PdfReader` and `pdfplumber`;
- require at least one page and a non-empty file;
- require metadata title `OI Wiki` and metadata or extracted front-matter text containing the source revision and Typst version;
- extract text from every page and reject `�`, `<未找到引用`, `TODO`, and raw `#include`/`#import` markers;
- normalize whitespace and compare every manifest title against the extracted text;
- require 100% title coverage, while reporting the precise missing titles;
- enumerate `/Link` annotations and count URI and internal destination links;
- call `pdffonts` and require every listed font row to report `emb=yes`;
- reject pages with no extracted text unless the page is adjacent to a level-1 section start or is the final back cover;
- return `VerificationReport` and print it as JSON from the CLI.

Use a `normalize_title()` helper that applies Unicode NFKC normalization, collapses whitespace, and strips Markdown backticks so title matching is stable.

- [ ] **Step 4: Run verifier unit tests**

Run: `rtk tmp/pdfs/venv/bin/python -m pytest test/typst_pdf/test_verify_pdf.py -q`

Expected: all tests pass.

- [ ] **Step 5: Commit verification tooling**

```bash
rtk git add scripts/typst-pdf/verify_pdf.py test/typst_pdf/test_verify_pdf.py
rtk git commit -m "test: verify generated OI Wiki PDF"
```

### Task 6: Upgrade the repository Typst workflow

**Files:**
- Modify: `.github/workflows/build-pdf-typst.yml`

- [ ] **Step 1: Write a workflow assertion before changing the workflow**

Run:

```bash
rtk rg -n 'typst-version: 0\.15\.0|scripts/typst-pdf/build\.sh' .github/workflows/build-pdf-typst.yml
```

Expected: no matches and exit 1.

- [ ] **Step 2: Replace the hand-written exporter setup**

Keep checkout and Node setup, change `typst-version` to `0.15.0`, install Poppler/ImageMagick/Noto fonts, create `tmp/pdfs/venv`, and install `scripts/typst-pdf/requirements.txt`, then call:

```yaml
      - name: Build and verify complete Typst document
        run: bash scripts/typst-pdf/build.sh

      - name: Upload artifact
        uses: actions/upload-artifact@v7
        with:
          name: OI-Wiki-Typst-0.15.0
          path: output/pdf/OI-Wiki-Typst-0.15.0.pdf
```

Do not retain a second independent clone/build sequence in the workflow; the shell entry point is the only build definition.

- [ ] **Step 3: Validate YAML and required strings**

Run:

```bash
rtk tmp/pdfs/venv/bin/python -c 'import yaml; yaml.safe_load(open(".github/workflows/build-pdf-typst.yml", encoding="utf-8"))'
rtk rg -n 'typst-version: 0\.15\.0|scripts/typst-pdf/build\.sh|OI-Wiki-Typst-0\.15\.0\.pdf' .github/workflows/build-pdf-typst.yml
```

Expected: YAML parsing exits 0 and all three strings are reported.

- [ ] **Step 4: Commit the CI upgrade**

```bash
rtk git add .github/workflows/build-pdf-typst.yml
rtk git commit -m "ci: build OI Wiki PDF with Typst 0.15.0"
```

### Task 7: Run the complete 466-page-source build and resolve conversion defects

**Files:**
- Potentially modify after a reproduced full-build failure: `scripts/typst-pdf/exporter-0.15.patch`
- Potentially modify after a reproduced layout defect: `scripts/typst-pdf/theme.typ`
- Potentially modify after a reproduced book-shell defect: `scripts/typst-pdf/book.typ`
- Generate: `output/pdf/OI-Wiki-Typst-0.15.0.pdf`

- [ ] **Step 1: Run the complete build**

Run: `rtk bash scripts/typst-pdf/build.sh`

Expected milestones:

```text
validated 466 navigation pages
converted 466 pages in navigation order
```

The command must finish with exit 0 and create `output/pdf/OI-Wiki-Typst-0.15.0.pdf`.

- [ ] **Step 2: Classify every diagnostic**

Run:

```bash
rtk rg -n -i 'error|warning|missing|not found|overflow|converg|fallback' tmp/pdfs/export.log tmp/pdfs/typst.log
```

Expected: no missing page/image/font/reference, overflow, layout convergence, or fatal conversion diagnostics. For benign third-party SVG metadata warnings, record the exact source image and later include its rendered page in visual QA.

- [ ] **Step 3: Fix conversion failures at the narrowest layer**

Use these routing rules:

- Markdown syntax or generated Typst defect: patch `exporter-0.15.patch` and add the failing construct to the theme smoke fixture.
- Missing function or visual style defect: change `theme.typ`.
- Cover, contents, metadata, section opener, header, or footer defect: change `book.typ`.
- Source article content defect: do not rewrite the article unless the source itself references a nonexistent local asset; report such cases before altering editorial content.

After each fix, run the smallest fixture first, then rerun the complete build.

- [ ] **Step 4: Re-run unit tests and full verification**

Run:

```bash
rtk tmp/pdfs/venv/bin/python -m pytest test/typst_pdf -q
rtk tmp/pdfs/venv/bin/python scripts/typst-pdf/verify_pdf.py \
  --pdf output/pdf/OI-Wiki-Typst-0.15.0.pdf \
  --manifest tmp/pdfs/nav-manifest.json \
  --source-revision "$(rtk git rev-parse --short=12 HEAD)" \
  --typst-version 0.15.0
```

Expected: all tests pass and the verifier reports `title_coverage: 1.0` with an empty `missing_titles` list.

- [ ] **Step 5: Commit only source/tool fixes, not the generated PDF**

```bash
rtk git add scripts/typst-pdf test/typst_pdf
rtk git commit -m "fix: handle full OI Wiki Typst export"
```

Skip this commit only if the first full build required no source changes.

### Task 8: Render and visually inspect the complete PDF

**Files:**
- Generate under `tmp/pdfs/rendered/`: PNG QA renders and contact sheets
- Preserve: `output/pdf/OI-Wiki-Typst-0.15.0.pdf`

- [ ] **Step 1: Record final PDF facts**

Run:

```bash
rtk typst --version
rtk pdfinfo output/pdf/OI-Wiki-Typst-0.15.0.pdf
rtk ls -lh output/pdf/OI-Wiki-Typst-0.15.0.pdf
rtk pdffonts output/pdf/OI-Wiki-Typst-0.15.0.pdf
```

Expected: Typst 0.15.0, readable PDF metadata, a nonzero page count/file size, and all fonts embedded.

- [ ] **Step 2: Determine representative and suspicious pages**

Use `pdftotext -layout` plus the PDF outline to collect page numbers for:

- cover, version page, first and last contents pages;
- all top-level section openers;
- one page each containing a long C++ block, display math, wide table, SVG, raster image, admonition, footnotes, internal link, and external link;
- every page associated with a retained benign SVG warning;
- pages whose extracted character count is 0 or whose page box differs from A4 portrait.

Write the sorted unique page list to `tmp/pdfs/qa-pages.txt`.

- [ ] **Step 3: Render the QA pages at 144 DPI**

For each page number in `qa-pages.txt`, run:

```bash
rtk pdftoppm -png -r 144 -f "$page" -l "$page" \
  output/pdf/OI-Wiki-Typst-0.15.0.pdf "tmp/pdfs/rendered/page-$page"
```

Expected: one PNG per selected page with no Poppler errors.

- [ ] **Step 4: Inspect every rendered PNG**

Check at full resolution for missing glyph boxes, overlapping text, clipped code/table/formula content, unexpected blank space, distorted images, poor contrast, inconsistent headers/footers, and incorrect section starts. Any defect returns to Task 7's routing rules and requires a full rebuild plus re-render of affected pages.

- [ ] **Step 5: Run a final all-page raster sanity pass**

Render all pages at 72 DPI to `tmp/pdfs/rendered/all/` and build contact sheets in manageable batches. Scan every contact sheet for black pages, repeated pages, sudden margin changes, anomalous blank pages, and images that dominate or vanish. Rebuild if any defect appears.

### Task 9: Final verification and delivery checkpoint

**Files:**
- Final artifact: `output/pdf/OI-Wiki-Typst-0.15.0.pdf`

- [ ] **Step 1: Run the complete verification suite from a clean generated state**

Run:

```bash
rtk tmp/pdfs/venv/bin/python -m pytest test/typst_pdf -q
rtk bash scripts/typst-pdf/build.sh
rtk git diff --check
rtk git status --short
```

Expected: tests and build pass, diff check is clean, only intentional source changes are tracked, and the ignored PDF exists at the final path.

- [ ] **Step 2: Confirm the artifact did not change after QA**

Run:

```bash
rtk shasum -a 256 output/pdf/OI-Wiki-Typst-0.15.0.pdf
rtk pdfinfo output/pdf/OI-Wiki-Typst-0.15.0.pdf
```

Record SHA-256, page count, file size, source revision, and build date for the handoff.

- [ ] **Step 3: Review commits and working tree**

Run:

```bash
rtk git log --oneline --decorate -10
rtk git status --short --branch
```

Expected: implementation commits are present, no accidental generated files are tracked, and no unrelated user files were modified.

- [ ] **Step 4: Deliver the PDF**

In the final response, describe the project in one paragraph, report Typst 0.15.0, page count, file size, source revision, SHA-256, structural/visual verification, and cite `output/pdf/OI-Wiki-Typst-0.15.0.pdf` exactly once as the output artifact.
