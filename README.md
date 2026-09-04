# xz

[xz](https://tukaani.org/xz/) as a single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/xz/actions/workflows/xz.yml/badge.svg)](https://github.com/unpins/xz/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install xz`.

## Usage

Run the `xz` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin xz -z file        # compress -> file.xz
unpin xz -d file.xz     # decompress
```

To install it onto your PATH:

```bash
unpin install xz
```

Installing also creates the `unxz`, `xzcat`, `lzma`, `unlzma`, `lzcat` commands.

## Man pages

The man pages for the shipped commands — `xz`, `unxz`, `xzcat`, `lzma`, `unlzma`, `lzcat` — are embedded in the binary; read one with `unpin man xz`, e.g. `unpin man xz unxz`. The pages for the standalone helpers (`xzdec`, `lzmadec`, `lzmainfo`) and the shell-script wrappers (`xzdiff`, `xzgrep`, `xzless`, `xzmore`, …) are dropped, since this package ships only `xz` and its aliases.
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

## Build notes

- **Multicall:** one `xz` binary; `unxz`/`xzcat`/`lzma`/`unlzma`/`lzcat` are `argv[0]`-dispatch aliases (`unpin install xz` creates the command names). The standalone helpers (`xzdec`/`lzmadec`/`lzmainfo`) and the shell-script wrappers are dropped under the single-binary policy.
- **Windows:** a single `xz.exe` targeting the mingw-w64 runtime — no companion DLLs.
- **Man pages:** the six shipped-command pages are embedded; read with `unpin man xz`.
- **Tests:** xz's test suite runs on native builds (19/19 pass under static-musl) and auto-skips on cross targets the build host can't execute.

