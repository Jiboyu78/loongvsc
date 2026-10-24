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

# nodejs.org publishes no linux-loong64 tarball for any release, so the Node.js
# build has to come from a mirror that hosts one. The archive also has to be
# verifiable: without a checksum the download is accepted unverified.
if [[ -z "${VSCODE_NODE_MIRROR:-}" ]]; then
	printf 'VSCODE_NODE_MIRROR must point at a mirror that hosts node-v*-linux-loong64.tar.gz (nodejs.org publishes none)\n' >&2
	exit 1
fi
if [[ -z "${VSCODE_NODE_CHECKSUM_FILE:-}" ]]; then
	printf 'VSCODE_NODE_CHECKSUM_FILE must point at the SHASUMS256.txt of the Node.js mirror\n' >&2
	exit 1
fi
if [[ ! -f "$VSCODE_NODE_CHECKSUM_FILE" ]]; then
	printf 'VSCODE_NODE_CHECKSUM_FILE does not exist: %s\n' "$VSCODE_NODE_CHECKSUM_FILE" >&2
	exit 1
fi

cd "$repo_root"
source build/azure-pipelines/linux/setup-env.sh
# The upstream ripgrep-universal package has no LoongArch artifact. Inject the
# audited native binary into the same layout consumed by the existing search
# service and package filters.
#
# The remote server (REH) is packaged from `remote/node_modules` and has its own
# copy of @vscode/ripgrep-universal, so the binary has to be injected there as
# well. The packaging filter keeps only the `linux-loong64` directory, so
# without this the remote server would ship without any ripgrep at all.
for ripgrep_root in node_modules remote/node_modules; do
	ripgrep_target="$ripgrep_root/@vscode/ripgrep-universal/bin/linux-loong64"
	if [[ ! -d "$ripgrep_root/@vscode/ripgrep-universal" ]]; then
		printf 'Expected %s/@vscode/ripgrep-universal to exist; run `npm ci` first\n' "$ripgrep_root" >&2
		exit 1
	fi
	mkdir -p "$ripgrep_target"
	cp "$ripgrep_dir/rg" "$ripgrep_target/rg"
	chmod +x "$ripgrep_target/rg"
done

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
