#!/usr/bin/env bash

# Scan the files tracked by this repository for credentials.
#
# `.gitignore` only covers the file *names* that are commonly used for secrets.
# A key pasted into a source file, a build script or a fixture is not covered by
# any ignore rule, so the tracked content is scanned as well.
#
# Usage:
#   scripts/check-for-secrets.sh
#
# Exit codes:
#   0  no credential found
#   1  at least one credential found
#   2  the scan itself failed
set -euo pipefail
export LC_ALL=C

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
	printf 'Not a git repository: %s\n' "$repo_root" >&2
	exit 2
fi

# Upstream fixtures that contain deliberately fake credentials. They are part of
# the public microsoft/vscode tree and must stay in sync with it.
allowlist=(
	'.porting/vscode/extensions/copilot/src/extension/chronicle/common/test/secretFilter.spec.ts'
	'.porting/vscode/extensions/copilot/src/platform/ignore/node/test/remoteContentExclusion.spec.ts'
	'.porting/vscode/extensions/copilot/test/prompts/fixtures/devcontainer/devContainerConfigTestData.json'
	'.porting/vscode/src/vs/platform/agentHost/test/node/claudeProxyAuth.test.ts'
	'.porting/vscode/src/vs/platform/agentHost/test/node/sshRemoteAgentHostService.test.ts'
	'.porting/vscode/src/vs/platform/terminal/test/node/terminalEnvironment.test.ts'
	'.porting/vscode/src/vs/platform/tunnel/test/node/selfSignedCert.test.ts'
	'.porting/vscode/build/azure-pipelines/common/publish.ts'
)

# High confidence credential shapes. Each pattern is deliberately anchored on a
# provider specific prefix so that ordinary source code does not match.
patterns=(
	'sk-ant-[A-Za-z0-9_-]{24,}'
	'sk-[A-Za-z0-9]{32,}'
	'ghp_[A-Za-z0-9]{36}'
	'gho_[A-Za-z0-9]{36}'
	'ghu_[A-Za-z0-9]{36}'
	'ghs_[A-Za-z0-9]{36}'
	'ghr_[A-Za-z0-9]{36}'
	'github_pat_[A-Za-z0-9_]{40,}'
	'glpat-[A-Za-z0-9_-]{20,}'
	'AKIA[0-9A-Z]{16}'
	'ASIA[0-9A-Z]{16}'
	'AIza[0-9A-Za-z_-]{30,}'
	'xox[baprs]-[A-Za-z0-9-]{10,}'
	'npm_[A-Za-z0-9]{30,}'
	# A real PEM block puts the header on a line of its own. Matching the end of
	# the line keeps the pattern from firing on the regular expressions that
	# search for key material in the source tree.
	'-----BEGIN [A-Z ]*PRIVATE KEY-----$'
	'_[Aa]uthToken=[A-Za-z0-9_-]{16,}'
	'"?[Aa]pi[-_]?[Kk]ey"?[[:space:]]*[:=][[:space:]]*"[A-Za-z0-9_-]{24,}"'
)

tracked_count=$(git ls-files | wc -l | tr -d ' ')
if [[ "$tracked_count" == "0" ]]; then
	printf 'No tracked files to scan\n'
	exit 0
fi

# `git grep` is used instead of ripgrep because it operates on the tracked
# files directly. That keeps the scan independent of the ignore rules (a
# secret in an otherwise ignored path is still found) and it avoids passing
# tens of thousands of paths on the command line.
failed=0
for pattern in "${patterns[@]}"; do
	# git grep exits 0 on a match, 1 on "no match" and >1 on an error.
	# -E is required: git grep defaults to POSIX *basic* regular expressions, in
	# which `{36}` would be a literal instead of a repetition count.
	status=0
	matches=$(git grep --extended-regexp --no-color --text --line-number -e "$pattern" 2>&1) || status=$?
	case "$status" in
		0)
			# Drop the hits that live in an allowlisted upstream fixture.
			filtered=''
			while IFS= read -r line; do
				[[ -z "$line" ]] && continue
				path=${line%%:*}
				skip=0
				for entry in "${allowlist[@]}"; do
					if [[ "$path" == "$entry" ]]; then
						skip=1
						break
					fi
				done
				if ((skip == 0)); then
					filtered+="$line"$'\n'
				fi
			done <<<"$matches"
			if [[ -n "$filtered" ]]; then
				printf 'Possible credential found (pattern: %s):\n%s' "$pattern" "$filtered" >&2
				failed=1
			fi
			;;
		1)
			;;
		*)
			printf 'git grep failed while scanning (pattern: %s): %s\n' "$pattern" "$matches" >&2
			exit 2
			;;
	esac
done

if ((failed != 0)); then
	printf 'Credential scan failed: remove the secrets above or rotate them\n' >&2
	exit 1
fi

printf 'Credential scan passed (%s tracked files)\n' "$tracked_count"
