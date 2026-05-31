# xz

Standalone build of [xz](https://tukaani.org/xz/).

[![CI](https://github.com/unpins/xz/actions/workflows/xz.yml/badge.svg)](https://github.com/unpins/xz/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Installation

Install with [unpin](https://github.com/unpins/unpin):

```bash
unpin xz
```

Or run without installing:

```bash
unpin run xz
```

`unpin install` creates the multicall aliases (`unxz`, `xzcat`, `lzma`, `unlzma`, `lzcat`) alongside `xz`. Each alias dispatches via `argv[0]` to the same binary, matching the behavior shipped by upstream's `bin/` directory.

## Build locally

```bash
nix build github:unpins/xz
./result/bin/xz
```

Or run directly:

```bash
nix run github:unpins/xz
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/xz/releases) page has standalone binaries for manual download.

## Man pages

The man pages for the shipped commands — `xz`, `unxz`, `xzcat`, `lzma`, `unlzma`, `lzcat` — are embedded in the binary; read one with `unpin man xz`, e.g. `unpin man xz unxz`. The pages for the standalone helpers (`xzdec`, `lzmadec`, `lzmainfo`) and the shell-script wrappers (`xzdiff`, `xzgrep`, `xzless`, `xzmore`, …) are dropped, since this package ships only `xz` and its multicall aliases.
