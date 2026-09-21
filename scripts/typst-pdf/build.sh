#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"

test "$(typst --version)" = "typst 0.15.0 (3ae52774)" || {
  echo "Typst 0.15.0 is required" >&2
  exit 1
}

mkdir -p tmp/pdfs output
python3 scripts/typst-pdf/check_nav.py \
  --config mkdocs.yml --docs docs --output tmp/pdfs/nav-manifest.json \
  --include edit-landing.md --include intro/docker-deploy.md --expect-count 466

EXPORTER_URL=https://github.com/OI-wiki/OI-Wiki-export.git
EXPORTER_SHA=a0743c869b166ccb4d3a42368f904a85384730a2
if [ ! -d tmp/OI-Wiki-export/.git ]; then
  git clone "$EXPORTER_URL" tmp/OI-Wiki-export
fi
git -C tmp/OI-Wiki-export fetch --depth 1 origin "$EXPORTER_SHA"
git -C tmp/OI-Wiki-export checkout --detach "$EXPORTER_SHA"
git -C tmp/OI-Wiki-export apply --check "$ROOT/scripts/typst-pdf/exporter-0.15.patch"
git -C tmp/OI-Wiki-export apply "$ROOT/scripts/typst-pdf/exporter-0.15.patch"

mkdir -p output/pdf
