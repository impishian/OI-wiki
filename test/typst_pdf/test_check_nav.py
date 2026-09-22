from pathlib import Path
import importlib.util

import pytest


_MODULE_PATH = Path(__file__).parents[2] / "scripts" / "typst-pdf" / "check_nav.py"
_SPEC = importlib.util.spec_from_file_location("check_nav", _MODULE_PATH)
assert _SPEC and _SPEC.loader
_MODULE = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_MODULE)
build_manifest = _MODULE.build_manifest


FIXTURES = Path(__file__).parent / "fixtures"


def test_build_manifest_preserves_nested_navigation_order_and_titles():
    manifest = build_manifest(
        FIXTURES / "mkdocs-valid.yml", FIXTURES / "docs"
    )

    assert [entry["path"] for entry in manifest] == ["intro.md", "algorithm.md"]
    assert [entry["title"] for entry in manifest] == ["入门", "基础"]


def test_build_manifest_rejects_duplicate_navigation_page(tmp_path):
    config = tmp_path / "mkdocs.yml"
    config.write_text(
        "nav:\n"
        "  - 简介:\n"
        "      - 入门: intro.md\n"
        "  - 重复: intro.md\n",
        encoding="utf-8",
    )
    (tmp_path / "intro.md").write_text("# 入门\n", encoding="utf-8")

    with pytest.raises(ValueError, match="duplicate navigation page: intro.md"):
        build_manifest(config, tmp_path)


def test_build_manifest_rejects_missing_navigation_page(tmp_path):
    config = tmp_path / "mkdocs.yml"
    config.write_text("nav:\n  - 缺失: missing.md\n", encoding="utf-8")

    with pytest.raises(FileNotFoundError, match="missing.md"):
        build_manifest(config, tmp_path)


def test_build_manifest_appends_included_pages_in_argument_order(tmp_path):
    config = tmp_path / "mkdocs.yml"
    config.write_text("nav:\n  - 入门: intro.md\n", encoding="utf-8")
    (tmp_path / "intro.md").write_text("# 入门\n", encoding="utf-8")
    (tmp_path / "extra-a.md").write_text("# A\n", encoding="utf-8")
    (tmp_path / "extra-b.md").write_text("# B\n", encoding="utf-8")

    manifest = build_manifest(
        config, tmp_path, extra_paths=["extra-b.md", "extra-a.md"]
    )

    assert [entry["path"] for entry in manifest] == [
        "intro.md",
        "extra-b.md",
        "extra-a.md",
    ]
    assert [entry["title"] for entry in manifest] == ["入门", "B", "A"]


def test_build_manifest_rejects_missing_included_page(tmp_path):
    config = tmp_path / "mkdocs.yml"
    config.write_text("nav:\n  - 入门: intro.md\n", encoding="utf-8")
    (tmp_path / "intro.md").write_text("# 入门\n", encoding="utf-8")

    with pytest.raises(FileNotFoundError, match="missing.md"):
        build_manifest(config, tmp_path, extra_paths=["missing.md"])


def test_build_manifest_requires_nav_list(tmp_path):
    config = tmp_path / "mkdocs.yml"
    config.write_text("nav:\n  入门: intro.md\n", encoding="utf-8")

    with pytest.raises(ValueError, match="top-level nav must be a list"):
        build_manifest(config, tmp_path)


def test_build_manifest_rejects_non_markdown_pages(tmp_path):
    config = tmp_path / "mkdocs.yml"
    config.write_text("nav:\n  - 首页: index.html\n", encoding="utf-8")
    (tmp_path / "index.html").write_text("<h1>首页</h1>\n", encoding="utf-8")

    with pytest.raises(ValueError, match="navigation page must be Markdown: index.html"):
        build_manifest(config, tmp_path)

    config.write_text("nav:\n  - 首页: index.md\n", encoding="utf-8")
    (tmp_path / "index.md").write_text("# 首页\n", encoding="utf-8")
    with pytest.raises(ValueError, match="navigation page must be Markdown: index.html"):
        build_manifest(config, tmp_path, extra_paths=["index.html"])


@pytest.mark.parametrize("page", ["../outside.md", "/outside.md"])
def test_build_manifest_rejects_pages_outside_docs_root(tmp_path, page):
    config = tmp_path / "mkdocs.yml"
    config.write_text(f"nav:\n  - 越界: {page}\n", encoding="utf-8")

    with pytest.raises(ValueError, match="navigation page outside docs root"):
        build_manifest(config, tmp_path)


def test_build_manifest_normalizes_paths_before_duplicate_check(tmp_path):
    config = tmp_path / "mkdocs.yml"
    config.write_text(
        "nav:\n  - 入门: intro.md\n  - 重复: sub/../intro.md\n", encoding="utf-8"
    )
    (tmp_path / "intro.md").write_text("# 入门\n", encoding="utf-8")

    with pytest.raises(ValueError, match="duplicate navigation page: intro.md"):
        build_manifest(config, tmp_path)
