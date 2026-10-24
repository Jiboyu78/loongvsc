# Code - OSS for LoongArch new-world Linux

## Project definition

This project is a downstream port of the MIT-licensed `microsoft/vscode` repository. The source
tree, not a repackaged Microsoft VS Code binary, is the product. The x86 package
`code_1.139.0-1790100840_amd64.deb` is retained only as a behavioral and package-layout reference.

The first source baseline is VS Code `1.139.0`, commit
`2242ebbb54efeeb0129e08e919e7e8d43033cd83`. The product identity remains **Code - OSS** unless a
separate, legally cleared downstream identity is introduced later.

## Compatibility target

The primary target is upstream/new-world LoongArch Linux, commonly referred to as LoongArch ABI
2.0. The build contract is deliberately expressed with the unambiguous toolchain terms:

- Node/build architecture: `loong64`
- Debian architecture: `loong64`
- RPM architecture: `loongarch64`
- GNU and Debian multiarch tuple: `loongarch64-linux-gnu`
- Rust target: `loongarch64-unknown-linux-gnu`
- C/C++ base ABI: `lp64d`
- Compiler baseline: `-march=loongarch64 -mabi=lp64d -mlsx`
- Dynamic interpreter: `/lib64/ld-linux-loongarch-lp64d.so.1`

The project must not link against an old-world LoongArch userspace or include x86-64, ARM, or MIPS
ELF payloads. `scripts/verify-loong64-new-world.sh` enforces this on the final package.

## Feature-parity baseline

The acceptance baseline is the open-source Linux ARM64 build of Code - OSS at the same upstream
commit. Architecture-neutral editor, workbench, extension host, terminal, search, Git, debug,
notebooks, accessibility, language services, settings sync implementations present in Code - OSS,
and remote server/CLI code must behave the same after replacing their native dependencies with
LoongArch builds.

"Parity with ARM64" does not mean copying components that are absent from the open-source
repository or licensed only for Microsoft's Visual Studio Code distribution. Microsoft branding,
the Visual Studio Marketplace service configuration, proprietary Remote Development components,
licensed debug adapters, and unavailable proprietary Copilot native runtimes are outside the
redistributable Code - OSS baseline. The default package therefore ships no Marketplace gallery,
Copilot extension/runtime, or Microsoft-distribution debug-adapter VSIX. Equivalent open services
or independently licensed artifacts can be integrated as separate downstream choices.

## Native port boundary

The TypeScript workbench is mostly architecture-neutral. The native boundary is:

1. Electron and Chromium 150 for LoongArch new-world Linux.
2. Node.js 24 `linux-loong64` for the extension host, remote server, and build tools.
3. Native modules such as `node-pty`, sqlite3, spdlog, native-keymap, watchdog, kerberos, parcel
   watcher, ripgrep, proxy resolver, authentication runtimes, and the Rust/OpenSSL CLI.
4. Extension target selection through `linux-loong64`.
5. Debian/RPM dependency generation and new-world ELF validation.

The community `darkyzhou/electron-loong64` fork is the current Electron bootstrap. It is an input,
not the architectural source of truth: every imported binary must pass this project's ABI and
feature tests before it can enter a release.

Upstream pins Electron 43.6.0 in `.npmrc`, and that build is only published for the architectures
Microsoft ships. The LoongArch fork publishes its own release series, so the Electron version has
to be selected explicitly with `VSCODE_ELECTRON_VERSION`; it must match a tag that actually exists
in the fork. The same applies to Node.js: nodejs.org does not publish a `linux-loong64` tarball at
all, so `VSCODE_NODE_MIRROR` must point at a mirror that hosts one.

## Build prerequisites

Build in a native LoongArch new-world environment, or a `linux/loong64` container under QEMU. A
native machine is strongly preferred for Electron/Chromium compilation and runtime tests.

```sh
export VSCODE_ARCH=loong64
export npm_config_arch=loong64

# The Electron fork. The version must exist as a release tag in the fork, and
# the checksum file must be that release's SHASUMS256.txt.
export VSCODE_ELECTRON_REPOSITORY=darkyzhou/electron-loong64
export VSCODE_ELECTRON_VERSION=43.7.7
export VSCODE_ELECTRON_CHECKSUM_FILE=/path/to/electron-loong64-SHASUMS256.txt
# Required: the GitHub API hands out the release asset only to an authenticated
# caller.
export GITHUB_TOKEN=...

# nodejs.org has no linux-loong64 tarball; the mirror has to host one.
export VSCODE_NODE_MIRROR=https://example.org/nodejs-mirror
export VSCODE_NODE_CHECKSUM_FILE=/path/to/nodejs-SHASUMS256.txt

export VSCODE_LOONG64_RIPGREP_DIR=/path/to/audited-loong64-ripgrep

# A cross sysroot, or `/` for a native new-world LoongArch build host.
export VSCODE_LOONG64_SYSROOT_DIR=/path/to/new-world-loong64-sysroot
export VSCODE_LOONG64_CHROMIUM_SYSROOT_DIR=$VSCODE_LOONG64_SYSROOT_DIR

# Optional when compilers live outside the sysroot.
# export VSCODE_LOONG64_CC=/usr/bin/loongarch64-linux-gnu-gcc
# export VSCODE_LOONG64_CXX=/usr/bin/loongarch64-linux-gnu-g++

./scripts/build-loong64.sh
```

The build script creates a `loong64` Debian package, extracts it, and rejects every ELF that is not
LoongArch LP64D or that requests a dynamic interpreter other than
`/lib64/ld-linux-loongarch-lp64d.so.1`. It also runs
`scripts/verify-code-oss-boundary.sh` to reject Marketplace/Copilot/Remote Development payloads
and proprietary product fields from the release tree.

## Release gates

A release is complete only after all of the following pass on real LoongArch hardware:

1. Startup under X11 and Wayland; sandbox, GPU acceleration, crash handler, and software rendering.
2. Extension host activation and install/uninstall/update of universal and `linux-loong64` VSIXes.
3. Integrated terminal and pseudoterminal resize, Unicode, shell integration, and process exit.
4. File watching, recursive search, Git operations, debugging, notebooks, webviews, authentication,
   keychain integration, clipboard, and accessibility smoke tests.
5. Local and remote server/CLI connection tests between LoongArch and x64/ARM64 clients.
6. Package install, upgrade, uninstall, dependency audit, desktop integration, and MIME handlers on
   the supported Deepin release.
7. A complete ELF inventory with no foreign architecture, old-world loader, or unreviewed native
   payload.

Until those gates pass, the output is a development port rather than a production release.
