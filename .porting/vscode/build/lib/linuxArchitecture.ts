/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

/**
 * Linux architecture names used by the VS Code build, Node.js, and package managers.
 *
 * LoongArch is deliberately kept as `loong64` at the VS Code/Node boundary.  This is the
 * spelling used by Node.js and by the LoongArch builds of Electron, esbuild and rollup.  The
 * Debian and RPM spellings are different and must not be inferred by string concatenation.
 */
export type LinuxBuildArch = 'x64' | 'armhf' | 'arm64' | 'loong64';

export const linuxBuildArchitectures: readonly LinuxBuildArch[] = ['x64', 'armhf', 'arm64', 'loong64'];

/** Upstream ("new-world") LoongArch Linux ABI contract used by this port. */
export const loong64NewWorldAbi = {
	debianArch: 'loong64',
	rpmArch: 'loongarch64',
	gnuTriple: 'loongarch64-linux-gnu',
	rustTarget: 'loongarch64-unknown-linux-gnu',
	baseAbi: 'lp64d',
	dynamicLinker: '/lib64/ld-linux-loongarch-lp64d.so.1',
	compilerFlags: ['-march=loongarch64', '-mabi=lp64d', '-mlsx'],
} as const;

export function isLinuxBuildArch(arch: string): arch is LinuxBuildArch {
	return linuxBuildArchitectures.includes(arch as LinuxBuildArch);
}

export function toNodeArch(arch: LinuxBuildArch): string {
	return arch === 'armhf' ? 'arm' : arch;
}

export function toDebianArch(arch: LinuxBuildArch): 'amd64' | 'armhf' | 'arm64' | 'loong64' {
	switch (arch) {
		case 'x64': return 'amd64';
		case 'armhf': return 'armhf';
		case 'arm64': return 'arm64';
		case 'loong64': return loong64NewWorldAbi.debianArch;
		default: throw new Error(`Unsupported Linux build architecture: ${arch}`);
	}
}

export function toRpmArch(arch: LinuxBuildArch): 'x86_64' | 'armv7hl' | 'aarch64' | 'loongarch64' {
	switch (arch) {
		case 'x64': return 'x86_64';
		case 'armhf': return 'armv7hl';
		case 'arm64': return 'aarch64';
		case 'loong64': return loong64NewWorldAbi.rpmArch;
		default: throw new Error(`Unsupported Linux build architecture: ${arch}`);
	}
}

/** GNU target triple used by upstream/new-world LoongArch Linux toolchains. */
export function toGnuTriple(arch: LinuxBuildArch): string {
	switch (arch) {
		case 'x64': return 'x86_64-linux-gnu';
		case 'armhf': return 'arm-rpi-linux-gnueabihf';
		case 'arm64': return 'aarch64-linux-gnu';
		case 'loong64': return loong64NewWorldAbi.gnuTriple;
		default: throw new Error(`Unsupported Linux build architecture: ${arch}`);
	}
}

/** Debian multiarch library directory used by dpkg-shlibdeps. */
export function toDebianMultiarch(arch: LinuxBuildArch): string {
	switch (arch) {
		case 'x64': return 'x86_64-linux-gnu';
		case 'armhf': return 'arm-linux-gnueabihf';
		case 'arm64': return 'aarch64-linux-gnu';
		case 'loong64': return loong64NewWorldAbi.gnuTriple;
		default: throw new Error(`Unsupported Linux build architecture: ${arch}`);
	}
}
