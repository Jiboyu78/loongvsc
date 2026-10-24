#!/usr/bin/env bash

# Build the open-source Code - OSS client and Debian package for the upstream
# LoongArch LP64D ("new-world") ABI.
# Electron/Chromium and the native node modules must already be available for
# linux-loong64; this script intentionally fails before packaging if an x86
# executable is accidentally selected.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sysroot=${VSCODE_LOONG64_SYSROOT_DIR:?Set VSCODE_LOONG64_SYSROOT_DIR to a Deepin LoongArch sysroot}

export VSCODE_ARCH=loong64
export npm_config_arch=loong64
export VSCODE_LOONG64_SYSROOT_DIR="$sysroot"
export VSCODE_LOONG64_CHROMIUM_SYSROOT_DIR="${VSCODE_LOONG64_CHROMIUM_SYSROOT_DIR:-$sysroot}"
export VSCODE_ELECTRON_REPOSITORY="${VSCODE_ELECTRON_REPOSITORY:-darkyzhou/electron-loong64}"

ripgrep_dir=${VSCODE_LOONG64_RIPGREP_DIR:?Set VSCODE_LOONG64_RIPGREP_DIR to a directory containing a native LP64D rg binary}
if [[ ! -x "$ripgrep_dir/rg" ]]; then
	printf 'Expected executable LoongArch ripgrep at %s/rg\n' "$ripgrep_dir" >&2
	exit 1
fi

# The upstream Electron CDN publishes no linux-loong64 artifact, so the build
# has to pull the browser from a LoongArch Electron fork.  Three things have to
# line up for that to work:
#   * the fork has to publish a release for the selected Electron version,
#   * the checksum of the downloaded archive has to be verifiable, and
#   * the GitHub API needs a token to hand out the release asset.
# Fail early with a precise message instead of an opaque 401/404 later on.
if [[ -n "${VSCODE_ELECTRON_REPOSITORY:-}" ]]; then
	if [[ -z "${VSCODE_ELECTRON_VERSION:-}" ]]; then
		printf 'VSCODE_ELECTRON_VERSION must select a release published by %s (upstream .npmrc pins a version the fork does not ship)\n' "$VSCODE_ELECTRON_REPOSITORY" >&2
		exit 1
	fi
	if [[ -z "${VSCODE_ELECTRON_CHECKSUM_FILE:-}" ]]; then
		printf 'VSCODE_ELECTRON_CHECKSUM_FILE must point at the SHASUMS256.txt published by %s\n' "$VSCODE_ELECTRON_REPOSITORY" >&2
		exit 1
	fi
	if [[ ! -f "$VSCODE_ELECTRON_CHECKSUM_FILE" ]]; then
		printf 'VSCODE_ELECTRON_CHECKSUM_FILE does not exist: %s\n' "$VSCODE_ELECTRON_CHECKSUM_FILE" >&2
		exit 1
	fi
	if [[ -z "${GITHUB_TOKEN:-}" && -z "${VSCODE_ELECTRON_TOKEN:-}" ]]; then
		printf 'GITHUB_TOKEN (or VSCODE_ELECTRON_TOKEN) is required to download the Electron release asset from %s\n' "$VSCODE_ELECTRON_REPOSITORY" >&2
		exit 1
	fi
fi

cd "$repo_root"
source build/azure-pipelines/linux/setup-env.sh

# The upstream ripgrep-universal package has no LoongArch artifact. Inject the
# audited native binary into the same layout consumed by the existing search
# service and package filters.
mkdir -p node_modules/@vscode/ripgrep-universal/bin/linux-loong64
cp "$ripgrep_dir/rg" node_modules/@vscode/ripgrep-universal/bin/linux-loong64/rg
chmod +x node_modules/@vscode/ripgrep-universal/bin/linux-loong64/rg

npm run gulp core-ci
npm run gulp vscode-linux-loong64-min-ci
npm run gulp vscode-linux-loong64-prepare-deb
npm run gulp vscode-linux-loong64-build-deb

deb_dir=.build/linux/deb/loong64/deb
deb=''
if [[ -d "$deb_dir" ]]; then
	deb=$(find "$deb_dir" -maxdepth 1 -type f -name '*.deb' -print -quit)
fi
if [[ -z "$deb" ]]; then
	printf 'LoongArch Debian package was not produced in %s\n' "$deb_dir" >&2
	exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
	printf 'dpkg-deb is required to validate %s\n' "$deb" >&2
	exit 1
fi

if [[ "$(dpkg-deb -f "$deb" Architecture)" != loong64 ]]; then
	printf 'Unexpected package architecture in %s\n' "$deb" >&2
	exit 1
fi

verify_root=$(mktemp -d)
trap 'rm -rf -- "$verify_root"' EXIT
dpkg-deb -x "$deb" "$verify_root"
"$repo_root/scripts/verify-loong64-new-world.sh" "$verify_root"
"$repo_root/scripts/verify-code-oss-boundary.sh" "$verify_root"

printf 'Built %s\n' "$deb"
