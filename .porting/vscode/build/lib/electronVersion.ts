/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import fs from 'fs';
import path from 'path';

const root = path.dirname(path.dirname(import.meta.dirname));

export function getElectronVersion(): Record<string, string> {
	const npmrc = fs.readFileSync(path.join(root, '.npmrc'), 'utf8');
	// The upstream `.npmrc` pins the Electron build that ships with this VS Code
	// release.  A LoongArch Electron fork does not necessarily publish that exact
	// version, so allow the port to select the fork's version explicitly.
	const electronVersion = process.env['VSCODE_ELECTRON_VERSION'] ?? /^target="(.*)"$/m.exec(npmrc)![1];
	const msBuildId = /^ms_build_id="(.*)"$/m.exec(npmrc)![1];
	return { electronVersion, msBuildId };
}
