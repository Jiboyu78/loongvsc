#!/usr/bin/env bash

# Verify that a packaged Code - OSS tree does not accidentally include
# Microsoft-distribution-only services, extensions, or native SDKs.
set -euo pipefail
export LC_ALL=C

root=${1:?Usage: verify-code-oss-boundary.sh <package-root>}

if [[ ! -d "$root" ]]; then
	printf 'Package root does not exist: %s\n' "$root" >&2
	exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
	printf 'rg (ripgrep) is required to verify the Code - OSS boundary\n' >&2
	exit 1
fi

# rg exits 0 on a match, 1 on "no match" and 2 on an error.  A scan error must
# never be mistaken for a clean tree, so the exit status is inspected instead of
# relying on `if rg ...` alone.
#
# --no-ignore/--hidden/--binary make sure that nothing inside the package is
# silently skipped: ignore files, dot files and native payloads all have to be
# part of the check.
scan() {
	local status=0 output
	output=$(rg --no-ignore --hidden --binary -n "$@" 2>&1) || status=$?
	case "$status" in
		0) return 0 ;;
		1) return 1 ;;
		*)
			printf 'ripgrep failed while scanning for prohibited content: %s\n' "$output" >&2
			return 2
			;;
	esac
}

product_json=$(find "$root" -type f -path '*/resources/app/product.json' -print -quit)
if [[ -z "$product_json" ]]; then
	printf 'Packaged product.json was not found under %s\n' "$root" >&2
	exit 1
fi

failure_count=0
reject_product_key() {
	local key=$1
	local status=0
	scan --fixed-strings "\"$key\"" "$product_json" >/dev/null || status=$?
	if ((status == 0)); then
		printf 'Proprietary product field present in %s: %s\n' "$product_json" "$key" >&2
		failure_count=$((failure_count + 1))
	elif ((status == 2)); then
		failure_count=$((failure_count + 1))
	fi
}

reject_product_key extensionsGallery
reject_product_key trustedExtensionAuthAccess
reject_product_key voiceWsUrl
reject_product_key defaultChatAgent

status=0
scan -i -e '@github/copilot-sdk' "$root" >/dev/null || status=$?
if ((status == 0)); then
	printf 'Copilot native SDK reference found under %s\n' "$root" >&2
	failure_count=$((failure_count + 1))
elif ((status == 2)); then
	failure_count=$((failure_count + 1))
fi

while IFS= read -r -d '' manifest; do
	status=0
	scan -i \
		-e 'GitHub\.copilot' \
		-e 'ms-vscode-remote\.' \
		-e 'ms-vscode\.remote' \
		"$manifest" >/dev/null || status=$?
	if ((status == 0)); then
		printf 'Microsoft-distribution extension identifier found in %s\n' "$manifest" >&2
		failure_count=$((failure_count + 1))
	elif ((status == 2)); then
		failure_count=$((failure_count + 1))
	fi
done < <(find "$root" -type f -name package.json -print0)

while IFS= read -r -d '' path; do
	case "$path" in
		*/extensions/copilot|*/extensions/copilot/*|*/node_modules/@github/copilot-sdk|*/node_modules/@github/copilot-sdk/*)
			printf 'Excluded Copilot payload present: %s\n' "$path" >&2
			failure_count=$((failure_count + 1))
			;;
	esac
done < <(find "$root" \( -type d -o -type f \) -print0)

if ((failure_count != 0)); then
	printf 'Code - OSS boundary verification failed: %d violation(s)\n' "$failure_count" >&2
	exit 1
fi

printf 'Verified Code - OSS proprietary boundary under %s\n' "$root"
