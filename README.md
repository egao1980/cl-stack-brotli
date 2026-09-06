# cl-stack-brotli

MIT. Ships **Brotli** shared libraries (`libbrotlicommon` + `libbrotlidec` +
`libbrotlienc`) as [cl-repository](https://github.com/egao1980/cl-repository)
platform overlays, plus CFFI and [`compression-protocol`](https://github.com/egao1980/compression-protocol)
methods for `:br`. HTTP `Content-Encoding: br` is
[`http-encoding-brotli`](https://github.com/egao1980/http-encoding-brotli).

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
;; Lisp API is compression-protocol. CFFI stays internal.
(asdf:load-system "cl-stack-brotli")
(compression-protocol:decompress
 (compression-protocol:compress octets :algorithm :br)
 :algorithm :br)
```

Smoke (linux/amd64): `scripts/smoke-clean-container.sh` (no `LD_LIBRARY_PATH`).

## Build natives locally

```bash
./scripts/build-brotli.sh          # BROTLI_VERSION=1.2.0 by default
# → lib/<os>-<arch>/libbrotli*
```
