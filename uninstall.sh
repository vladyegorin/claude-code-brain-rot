#!/bin/sh
set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "Claude Code Brain Rot — Uninstaller"
echo ""

# ── Python check ──────────────────────────────────────────────────────────────
printf "Checking Python... "
if command -v python3 >/dev/null 2>&1; then
    PY_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PY_CMD="python"
else
    echo "NOT FOUND"
    echo "  Python 3.8+ is required to run the uninstaller."
    echo "    macOS:  brew install python3"
    echo "    Linux:  sudo apt install python3"
    exit 1
fi

PY_VERSION=$($PY_CMD --version 2>&1 | sed 's/Python //')
PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 8 ]; }; then
    echo "FAIL ($PY_VERSION)"
    echo "  Python 3.8+ required."
    exit 1
fi
echo "OK ($PY_VERSION)"

# ── Remove settings entries ───────────────────────────────────────────────────
printf "Removing settings entries... "
"$PY_CMD" "$REPO_ROOT/scripts/merge_settings.py" remove --repo-root "$REPO_ROOT" >/dev/null
echo "OK"

# ── Remove slash command files ────────────────────────────────────────────────
printf "Removing slash commands... "
COMMANDS_DEST="$HOME/.claude/commands"
if [ -d "$REPO_ROOT/commands" ]; then
    for FILE in "$REPO_ROOT/commands/"*.md; do
        [ -e "$FILE" ] || continue
        TARGET="$COMMANDS_DEST/$(basename "$FILE")"
        [ -f "$TARGET" ] && rm "$TARGET"
    done
else
    # Fallback: remove brainrot-*.md files installed by this plugin
    for FILE in "$COMMANDS_DEST"/brainrot-*.md; do
        [ -f "$FILE" ] && rm "$FILE"
    done
fi
echo "OK"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "Done! Brain rot has been uninstalled."
echo "Your ~/.brainrot state directory has been preserved."
echo ""
