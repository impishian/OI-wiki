"""Validate the pages referenced by a MkDocs navigation and emit a manifest."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import yaml


def _heading(path: Path, fallback: str) -> str:
    """Return the first Markdown H1, or a useful fallback title."""
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^#\s+(.+?)\s*$", text, flags=re.MULTILINE)
    return match.group(1).strip() if match else fallback


def _walk(
    node: Any,
    docs_dir: Path,
    seen: set[str],
    title: str | None = None,
) -> list[dict[str, str]]:
    """Walk a MkDocs nav node, preserving order and validating page paths."""
    if isinstance(node, list):
        manifest: list[dict[str, str]] = []
        for child in node:
            manifest.extend(_walk(child, docs_dir, seen))
        return manifest

    if isinstance(node, dict):
        manifest = []
        for label, child in node.items():
            if not isinstance(label, str):
                raise TypeError(f"navigation label must be a string: {label!r}")
            manifest.extend(_walk(child, docs_dir, seen, label))
        return manifest

    if isinstance(node, str):
        page = Path(node)
        page_key = page.as_posix()
        if page.suffix.lower() != ".md":
            raise ValueError(f"navigation page must be Markdown: {page_key}")
        if page_key in seen:
            raise ValueError(f"duplicate navigation page: {page_key}")
        path = docs_dir / page
        if not path.is_file():
            raise FileNotFoundError(f"navigation page does not exist: {page_key}")
        seen.add(page_key)
        return [{"path": page_key, "title": title or _heading(path, page.stem)}]

    raise TypeError(f"unsupported navigation node: {node!r}")


def build_manifest(
    config_path: Path,
    docs_dir: Path,
    extra_paths: list[str] | tuple[str, ...] | None = None,
) -> list[dict[str, str]]:
    """Load ``config_path`` and return its validated navigation manifest."""
    with config_path.open(encoding="utf-8") as stream:
        config = yaml.load(stream, Loader=yaml.BaseLoader)
    if not isinstance(config, dict) or "nav" not in config:
        raise ValueError("configuration must contain a nav mapping")
    if not isinstance(config["nav"], list):
        raise ValueError("top-level nav must be a list")
    seen: set[str] = set()
    manifest = _walk(config["nav"], docs_dir, seen)
    for page in extra_paths or ():
        manifest.extend(_walk(page, docs_dir, seen))
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--docs", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--include", action="append", default=[])
    parser.add_argument("--expect-count", type=int)
    args = parser.parse_args()

    manifest = build_manifest(args.config, args.docs, extra_paths=args.include)
    if args.expect_count is not None and len(manifest) != args.expect_count:
        parser.error(
            f"expected {args.expect_count} navigation pages, found {len(manifest)}"
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"validated {len(manifest)} navigation pages")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
