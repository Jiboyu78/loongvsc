/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import assert from 'assert';
import { suite, test } from 'node:test';
import { loong64NewWorldAbi, toDebianArch, toDebianMultiarch, toGnuTriple, toRpmArch } from '../linuxArchitecture.ts';

suite('linuxArchitecture', () => {
	test('defines the upstream LoongArch LP64D ABI contract', () => {
		assert.deepStrictEqual({
			debianArch: toDebianArch('loong64'),
			rpmArch: toRpmArch('loong64'),
			gnuTriple: toGnuTriple('loong64'),
			multiarch: toDebianMultiarch('loong64'),
			baseAbi: loong64NewWorldAbi.baseAbi,
			dynamicLinker: loong64NewWorldAbi.dynamicLinker,
			compilerFlags: loong64NewWorldAbi.compilerFlags,
		}, {
			debianArch: 'loong64',
			rpmArch: 'loongarch64',
			gnuTriple: 'loongarch64-linux-gnu',
			multiarch: 'loongarch64-linux-gnu',
			baseAbi: 'lp64d',
			dynamicLinker: '/lib64/ld-linux-loongarch-lp64d.so.1',
			compilerFlags: ['-march=loongarch64', '-mabi=lp64d', '-mlsx'],
		});
	});
});
