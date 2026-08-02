# cl-stack-brotli

MIT. Ships **Brotli** shared libraries (`libbrotlicommon` + `libbrotlidec` +
`libbrotlienc`) as [cl-repository](https://github.com/egao1980/cl-repository)
platform overlays, plus a thin CFFI `compress` / `decompress` API for HTTP
`Content-Encoding: br`.

| | |
|--|--|
| ASDF | `cl-stack-brotli` |
| GHCR | `ghcr.io/egao1980/cl-systems/cl-stack-brotli:<brotli-ver>` |
| Tracks | [egao1980/cl-stack#45](https://github.com/egao1980/cl-stack/issues/45) |
| Upstream | [google/brotli](https://github.com/google/brotli) **v1.2.0** |

## Platforms

| OS | Arch | Runner |
|----|------|--------|
| linux | amd64 | `ubuntu-latest` |
| linux | arm64 | `ubuntu-24.04-arm` |
| darwin | arm64 | `macos-latest` |
| windows | amd64 | `windows-latest` |

## Consumer

```lisp
;; cl-repository install writes cl-repo-init.lisp (pushes native/ + absolute preload).
;; Local/ASDF: ensure-brotli pushes system native/ and lib/<os>-<arch>/ onto
;; cffi:*foreign-library-directories* — do not set LD_LIBRARY_PATH.
(asdf:load-system "cl-stack-brotli")
(cl-stack-brotli:ensure-brotli) ; => T, "1.2.0"
(cl-stack-brotli:decompress (cl-stack-brotli:compress octets))
```

Smoke (linux/amd64): `scripts/smoke-clean-container.sh` (no `LD_LIBRARY_PATH`).

## Build natives locally

```bash
./scripts/build-brotli.sh          # BROTLI_VERSION=1.2.0 by default
# → lib/<os>-<arch>/libbrotli*
```
