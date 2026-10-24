#!/usr/bin/env bash

# Verify that every ELF in a packaged Code - OSS tree targets the upstream
# LoongArch LP64D ("new-world") ABI and that no foreign-architecture binary
# has entered the product through an npm package or bundled tool.
set -euo pipefail
export LC_ALL=C

root=${1:?Usage: verify-loong64-new-world.sh <package-root>}
expected_interpreter=/lib64/ld-linux-loongarch-lp64d.so.1

if [[ ! -d "$root" ]]; then
	printf 'Package root does not exist: %s\n' "$root" >&2
	exit 1
fi

for command_name in file readelf; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		printf '%s is required to verify LoongArch binaries\n' "$command_name" >&2
		exit 1
	fi
done

elf_count=0
failure_count=0
while IFS= read -r -d '' candidate; do
	file_description=$(file -b "$candidate")
	if [[ "$file_description" != *ELF* ]]; then
		continue
	fi

	elf_count=$((elf_count + 1))
	if [[ "$file_description" != *LoongArch* ]]; then
		printf 'Foreign ELF architecture: %s: %s\n' "$candidate" "$file_description" >&2
		failure_count=$((failure_count + 1))
		continue
	fi

	header=$(readelf -h "$candidate" 2>/dev/null) || header=''
	if [[ -z "$header" ]]; then
		printf 'Unreadable ELF header: %s\n' "$candidate" >&2
		failure_count=$((failure_count + 1))
		continue
	fi
	if [[ "$header" != *"Machine:"*"LoongArch"* ]] || [[ "$header" != *"DOUBLE-FLOAT"* ]]; then
		printf 'Not a LoongArch LP64D ELF: %s\n' "$candidate" >&2
		failure_count=$((failure_count + 1))
	fi

	# A failed readelf must not silently skip the interpreter check: an
	# unreadable program header table is a verification failure, not a pass.
	program_headers=$(readelf -l "$candidate" 2>/dev/null) || program_headers=''
	if [[ -z "$program_headers" ]]; then
		printf 'Unreadable program headers: %s\n' "$candidate" >&2
		failure_count=$((failure_count + 1))
		continue
	fi
	if [[ "$program_headers" == *"Requesting program interpreter:"* ]] &&
		[[ "$program_headers" != *"$expected_interpreter"* ]]; then
		printf 'Unexpected dynamic interpreter: %s\n' "$candidate" >&2
		failure_count=$((failure_count + 1))
	fi
done < <(find "$root" \( -type f -o -type l \) -print0)

if ((elf_count == 0)); then
	printf 'No ELF files found under %s\n' "$root" >&2
	exit 1
fi

if ((failure_count != 0)); then
	printf 'LoongArch new-world verification failed: %d of %d ELF files rejected\n' "$failure_count" "$elf_count" >&2
	exit 1
fi

printf 'Verified %d LoongArch LP64D ELF files under %s\n' "$elf_count" "$root"
