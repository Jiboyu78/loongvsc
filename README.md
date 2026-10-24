# loongvsc

为龙芯新世界（LoongArch new-world / `loong64`，LP64D ABI）移植的原生 **Code - OSS**（尚未完成）。

A downstream development tree for an open-source Code - OSS build targeting upstream/new-world
LoongArch Linux (`loong64`, LP64D / ABI 2.0 terminology).

## Status

The port is **not finished**. The upstream feature baseline, the native port boundary and the
release gates are described in [`LOONGARCH64-PORT.md`](.porting/LOONGARCH64-PORT.md). In short:

- The TypeScript workbench is taken from upstream and is architecture neutral.
- The native boundary (Electron/Chromium, Node.js, `node-pty`, `sqlite3`, `spdlog`, ripgrep, the
  Rust/OpenSSL CLI, …) has to be supplied as LoongArch LP64D builds.
- The Debian package is rejected unless every ELF in it is LoongArch LP64D and asks for
  `/lib64/ld-linux-loongarch-lp64d.so.1`.
- The package is rejected if it still carries Marketplace, Copilot or Remote Development payloads.

## Repository layout

| Path | Content |
| --- | --- |
| `.porting/LOONGARCH64-PORT.md` | Port contract, compatibility target and release gates. |
| `.porting/deb-control/` | Debian packaging fragments (`control`, maintainer scripts). |
| `.porting/vscode/` | The Code - OSS source checkout with the LoongArch port applied. |
| `scripts/check-for-secrets.sh` | Credential scanner for the tracked files. |

The source checkout is upstream `microsoft/vscode` at commit
`2242ebbb54efeeb0129e08e919e7e8d43033cd83` (VS Code `1.139.0`) plus the LoongArch port. The x86
`.deb` and the tree extracted from it are *reference input* only; they are not product source, they
are never relabeled as a LoongArch package, and they are not part of this repository.

## Building

```sh
cd .porting/vscode
npm ci

export VSCODE_ARCH=loong64
export npm_config_arch=loong64

# Electron fork. The version must exist as a release tag in the fork and the
# checksum file must be that release's SHASUMS256.txt.
export VSCODE_ELECTRON_REPOSITORY=darkyzhou/electron-loong64
export VSCODE_ELECTRON_VERSION=43.7.7
export VSCODE_ELECTRON_CHECKSUM_FILE=/path/to/electron-loong64-SHASUMS256.txt
export GITHUB_TOKEN=...

# nodejs.org publishes no linux-loong64 tarball, so a mirror is required.
export VSCODE_NODE_MIRROR=https://example.org/nodejs-mirror
export VSCODE_NODE_CHECKSUM_FILE=/path/to/nodejs-SHASUMS256.txt

export VSCODE_LOONG64_RIPGREP_DIR=/path/to/audited-loong64-ripgrep
export VSCODE_LOONG64_SYSROOT_DIR=/path/to/new-world-loong64-sysroot
export VSCODE_LOONG64_CHROMIUM_SYSROOT_DIR=$VSCODE_LOONG64_SYSROOT_DIR

./scripts/build-loong64.sh
```

The build requires a native or emulated `linux/loong64` environment, a new-world LP64D sysroot and
a LoongArch Electron/Chromium build. See [`LOONGARCH64-PORT.md`](.porting/LOONGARCH64-PORT.md) for
the full list of environment variables and the reasoning behind them.

## Keeping credentials out of the repository

- [`.gitignore`](.gitignore) excludes environment files, private keys, npm credentials and the
  oversized reference artifacts.
- `scripts/check-for-secrets.sh` scans the tracked files for provider specific credential
  patterns, because an ignore rule cannot catch a key that was pasted into a source file.

```sh
scripts/check-for-secrets.sh
```

## License

MIT — see [`LICENSE`](LICENSE). The vendored Code - OSS sources under `.porting/vscode/` are MIT
licensed as well; see `.porting/vscode/LICENSE.txt` and `ThirdPartyNotices.txt`.
