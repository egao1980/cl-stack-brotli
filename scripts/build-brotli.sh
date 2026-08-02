#!/usr/bin/env bash
# Build shared libbrotli{common,dec,enc} into lib/<os>-<arch>/.
# Usage: ./scripts/build-brotli.sh
# Env: BROTLI_VERSION (default 1.2.0), DEST_DIR (optional override)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BROTLI_VERSION="${BROTLI_VERSION:-1.2.0}"
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "$uname_s" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) echo "unsupported OS: $uname_s (Windows: use build-brotli.ps1)" >&2; exit 1 ;;
esac
case "$uname_m" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "unsupported arch: $uname_m" >&2; exit 1 ;;
esac

OUT="${DEST_DIR:-$ROOT/lib/${os}-${arch}}"
BUILD="$ROOT/build/brotli-${BROTLI_VERSION}-${os}-${arch}"
SRC_TGZ="$ROOT/build/brotli-${BROTLI_VERSION}.tar.gz"
SRC_URL="https://github.com/google/brotli/archive/refs/tags/v${BROTLI_VERSION}.tar.gz"

mkdir -p "$ROOT/build" "$OUT"
if [[ ! -f "$SRC_TGZ" ]]; then
  echo "==> download $SRC_URL"
  curl -fsSL "$SRC_URL" -o "$SRC_TGZ"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
tar -xzf "$SRC_TGZ" -C "$BUILD" --strip-components=1

echo "==> cmake/build brotli ${BROTLI_VERSION} -> $OUT"
cmake -S "$BUILD" -B "$BUILD/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$BUILD/prefix" \
  -DBUILD_SHARED_LIBS=ON
cmake --build "$BUILD/build" -j"$JOBS"
cmake --install "$BUILD/build"

rm -rf "$OUT"
mkdir -p "$OUT"
shopt -s nullglob
libs=(
  "$BUILD/prefix/lib"/libbrotli*.so*
  "$BUILD/prefix/lib"/libbrotli*.dylib
  "$BUILD/prefix/lib64"/libbrotli*.so*
)
if ((${#libs[@]} == 0)); then
  echo "brotli shared libraries not found under $BUILD/prefix" >&2
  ls -la "$BUILD/prefix/lib" "$BUILD/prefix/lib64" 2>/dev/null || true
  exit 1
fi
cp -a "${libs[@]}" "$OUT/"

# Unversioned names for CFFI (:unix "libbrotli*.so" / darwin .dylib)
for base in libbrotlicommon libbrotlidec libbrotlienc; do
  if [[ "$os" == "linux" ]]; then
    if [[ ! -e "$OUT/${base}.so" ]]; then
      cand="$(ls -1 "$OUT"/${base}.so.* 2>/dev/null | head -1 || true)"
      [[ -n "$cand" ]] && ln -sfn "$(basename "$cand")" "$OUT/${base}.so"
    fi
  elif [[ "$os" == "darwin" ]]; then
    if [[ ! -e "$OUT/${base}.dylib" ]]; then
      cand="$(ls -1 "$OUT"/${base}.*.dylib 2>/dev/null | head -1 || true)"
      [[ -n "$cand" ]] && ln -sfn "$(basename "$cand")" "$OUT/${base}.dylib"
    fi
  fi
done

if [[ "$os" == "linux" ]] && command -v patchelf >/dev/null; then
  for f in "$OUT"/libbrotli*.so*; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    patchelf --set-rpath '$ORIGIN' "$f"
  done
elif [[ "$os" == "darwin" ]] && command -v install_name_tool >/dev/null; then
  for f in "$OUT"/libbrotli*.dylib; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    install_name_tool -id "@loader_path/$(basename "$f")" "$f" 2>/dev/null || true
  done
  # Point enc/dec at sibling common
  for dep in libbrotlidec libbrotlienc; do
    real="$(cd "$OUT" && realpath "${dep}.dylib" 2>/dev/null || readlink "${dep}.dylib" || true)"
    [[ -n "$real" && "$real" != /* ]] && real="$OUT/$real"
    [[ -f "${real:-}" ]] || continue
    common_real="$(cd "$OUT" && realpath libbrotlicommon.dylib 2>/dev/null || readlink libbrotlicommon.dylib || true)"
    [[ -n "$common_real" && "$common_real" != /* ]] && common_real="$OUT/$common_real"
    [[ -f "${common_real:-}" ]] || continue
    # Rewrite any absolute install-prefix refs to @loader_path
    otool -L "$real" | awk '/libbrotlicommon/ {print $1}' | while read -r old; do
      [[ "$old" == *"libbrotlicommon"* ]] || continue
      install_name_tool -change "$old" "@loader_path/$(basename "$common_real")" "$real" 2>/dev/null || true
    done
  done
fi

echo "==> staged:"
ls -la "$OUT"
echo "OK: brotli ${BROTLI_VERSION} -> ${os}/${arch}"
