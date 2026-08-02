#!/usr/bin/env bash
# Rewrite ASDF :version and +brotli-version+ to match the published Brotli release.
# Usage: ./scripts/sync-package-version.sh <version>
set -euo pipefail

VERSION="${1:?version required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

sed -i.bak 's/:version "[^"]*"/:version "'"${VERSION}"'"/' "$ROOT/cl-stack-brotli.asd"
sed -i.bak 's/(defparameter +brotli-version+ "[^"]*"/(defparameter +brotli-version+ "'"${VERSION}"'"/' "$ROOT/src/api.lisp"
rm -f "$ROOT/cl-stack-brotli.asd.bak" "$ROOT/src/api.lisp.bak"
