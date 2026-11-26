#!/bin/bash
# Fail if Godot 4.7.2 rewrites tracked files after a headless import, editor
# open, short run, and a UID pass. Used by CI so a missing uid:// reference
# cannot silently return.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-godot}"
if [[ ! -x "$GODOT" ]] && command -v "$GODOT" >/dev/null 2>&1; then
	GODOT="$(command -v "$GODOT")"
fi
if [[ ! -x "$GODOT" ]]; then
	echo "check_editor_clean: Godot not found at ${GODOT}" >&2
	exit 1
fi

if [[ "${SKIP_IMPORT:-}" != "1" ]]; then
	"$GODOT" --headless --path . --import
fi
"$GODOT" --headless --path . --editor --quit
"$GODOT" --headless --path . --quit-after 60
"$GODOT" --headless --path . -s res://tools/ensure_resource_uids.gd

if [[ -n "$(git status --porcelain)" ]]; then
	echo "check_editor_clean: Godot left the checkout dirty:" >&2
	git status --porcelain >&2
	git diff --stat >&2
	exit 1
fi
echo "check_editor_clean: checkout is clean"
