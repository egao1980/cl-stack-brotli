#!/usr/bin/env bash
# Clean ubuntu:24.04 linux/amd64 smoke against GHCR cl-stack-brotli.
set -euo pipefail

VERSION="${1:-1.2.0}"
IMAGE="ghcr.io/egao1980/cl-systems/cl-stack-brotli:${VERSION}"
CACHE="${CACHE:-/tmp/cl-stack-brotli-smoke-cache}"
PKG="$CACHE/pkg/cl-stack-brotli-${VERSION}"
QL="$CACHE/quicklisp"

mkdir -p "$CACHE/pull" "$CACHE/pkg"
if [[ ! -f "$PKG/native/libbrotlicommon.so" && ! -f "$PKG/native/libbrotlienc.so" ]]; then
  command -v oras >/dev/null || { echo "need oras" >&2; exit 1; }
  rm -rf "${CACHE}/pull/"* "${CACHE}/pkg/"*
  oras pull --platform linux/amd64 "$IMAGE" -o "$CACHE/pull/"
  for f in "$CACHE/pull"/*.tar.gz; do tar -xzf "$f" -C "$CACHE/pkg/"; done
fi

SMOKE_LISP="$CACHE/smoke.lisp"
cat >"$SMOKE_LISP" <<'EOF'
(require :asdf) (require :uiop)
(defvar *pkg* (uiop:getenv "CL_STACK_BROTLI_ROOT"))
(asdf:initialize-source-registry
 `(:source-registry (:directory ,(uiop:ensure-directory-pathname *pkg*))
                    :inherit-configuration))
(ql:quickload '("cffi" "cl-stack-brotli") :silent t)
(multiple-value-bind (ok ver) (cl-stack-brotli:ensure-brotli)
  (format t "~&ensure-brotli => ~A ~A~%" ok ver))
(let* ((s "hello brotli overlay")
       (raw (map '(simple-array (unsigned-byte 8) (*)) #'char-code s))
       (enc (cl-stack-brotli:compress raw :quality 5))
       (dec (cl-stack-brotli:decompress enc)))
  (unless (equalp raw dec)
    (error "round-trip mismatch"))
  (format t "~&round-trip OK (~D -> ~D bytes)~%" (length raw) (length enc)))
(format t "~&SMOKE OK~%")
(uiop:quit 0)
EOF

if [[ ! -f "$QL/setup.lisp" ]]; then
  docker run --rm --platform linux/amd64 \
    -e DEBIAN_FRONTEND=noninteractive \
    -v "$QL:/ql" \
    ubuntu:24.04 \
    bash -c 'apt-get update -qq && apt-get install -y -qq ca-certificates curl sbcl >/dev/null \
      && curl -fsSL -o /tmp/ql.lisp https://beta.quicklisp.org/quicklisp.lisp \
      && sbcl --noinform --non-interactive --load /tmp/ql.lisp \
           --eval "(quicklisp-quickstart:install :path #p\"/ql/\")" >/dev/null'
fi

docker run --rm --platform linux/amd64 \
  -e DEBIAN_FRONTEND=noninteractive \
  -e CL_STACK_BROTLI_ROOT=/opt/cl-stack-brotli \
  -e LD_LIBRARY_PATH=/opt/cl-stack-brotli/native \
  -v "$PKG:/opt/cl-stack-brotli:ro" \
  -v "$QL:/ql:ro" \
  -v "$SMOKE_LISP:/opt/smoke.lisp:ro" \
  ubuntu:24.04 \
  bash -c 'apt-get update -qq && apt-get install -y -qq ca-certificates sbcl >/dev/null \
    && sbcl --noinform --non-interactive --load /ql/setup.lisp --load /opt/smoke.lisp'
