#!/usr/bin/env python3
"""
merge_settings.py — add or remove brain-rot hook/permission entries
in a Claude Code global settings.json file.

CLI:
  merge_settings.py add    --repo-root <ABS> --py-cmd <python|python3> [--settings <path>]
  merge_settings.py remove --repo-root <ABS>                           [--settings <path>]

The script owns the hook/permission entry definitions and builds them from
--repo-root and --py-cmd. Installers only need to supply those two values.
"""

import argparse
import json
import os
import sys

DEFAULT_SETTINGS = os.path.expanduser("~/.claude/settings.json")

# Ordered list of (event, file, extra_arg) tuples that define our 4 hooks.
# file is relative to repo root; extra_arg may be None.
_HOOK_DEFS = [
    ("UserPromptSubmit", "brain_rot.py",        "start"),
    ("PostToolUse",      "scripts/think.py",    None),
    ("Notification",     "brain_rot.py",        "notify"),
    ("Stop",             "scripts/notify.py",   None),
]


def _build_command(py_cmd, repo_root, rel_file, extra_arg):
    """Return the shell command string for a hook entry."""
    path = repo_root + "/" + rel_file
    cmd = '{} "{}"'.format(py_cmd, path)
    if extra_arg:
        cmd += " " + extra_arg
    return cmd


def _build_hook_commands(py_cmd, repo_root):
    """Return dict mapping event name -> command string."""
    return {
        event: _build_command(py_cmd, repo_root, rel_file, extra_arg)
        for event, rel_file, extra_arg in _HOOK_DEFS
    }


def _build_permissions(repo_root):
    """Return the two allow strings for our entries (always python + python3)."""
    return [
        'Bash(python "{}/brain_rot.py" *)'.format(repo_root),
        'Bash(python3 "{}/brain_rot.py" *)'.format(repo_root),
    ]


def _is_our_hook(entry, repo_root):
    """True iff the hook entry object is ours (inner command contains repo_root)."""
    try:
        for hook in entry.get("hooks", []):
            if repo_root in hook.get("command", ""):
                return True
    except (AttributeError, TypeError):
        pass
    return False


def _is_our_permission(allow_str, repo_root):
    """True iff the allow string is ours (contains repo_root AND brain_rot.py)."""
    return repo_root in allow_str and "brain_rot.py" in allow_str


def _load(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _save(path, data):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


def _normalize_root(repo_root):
    """Strip any trailing path separators so comparisons are consistent."""
    return repo_root.rstrip("/\\")


# ── add ───────────────────────────────────────────────────────────────────────

def cmd_add(repo_root, py_cmd, settings_path):
    repo_root = _normalize_root(repo_root)
    commands = _build_hook_commands(py_cmd, repo_root)
    permissions = _build_permissions(repo_root)

    if not os.path.exists(settings_path):
        parent = os.path.dirname(settings_path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        data = {
            "permissions": {"allow": permissions},
            "hooks": {
                event: [{"hooks": [{"type": "command", "command": cmd}]}]
                for event, cmd in commands.items()
            },
        }
        _save(settings_path, data)
        print("Created {} with brain-rot entries.".format(settings_path))
        return

    data = _load(settings_path)

    # ── hooks ────────────────────────────────────────────────────────────────
    if "hooks" not in data:
        data["hooks"] = {}

    for event, cmd in commands.items():
        if event not in data["hooks"]:
            data["hooks"][event] = []
        already = any(_is_our_hook(e, repo_root) for e in data["hooks"][event])
        if not already:
            data["hooks"][event].append(
                {"hooks": [{"type": "command", "command": cmd}]}
            )

    # ── permissions ──────────────────────────────────────────────────────────
    if "permissions" not in data:
        data["permissions"] = {}
    if "allow" not in data["permissions"]:
        data["permissions"]["allow"] = []

    for perm in permissions:
        if perm not in data["permissions"]["allow"]:
            data["permissions"]["allow"].append(perm)

    _save(settings_path, data)
    print("Updated {} with brain-rot entries.".format(settings_path))


# ── remove ────────────────────────────────────────────────────────────────────

def cmd_remove(repo_root, settings_path):
    if not os.path.exists(settings_path):
        print("Settings file not found — nothing to remove.")
        return

    repo_root = _normalize_root(repo_root)
    data = _load(settings_path)

    # ── hooks ────────────────────────────────────────────────────────────────
    if "hooks" in data:
        for event in list(data["hooks"].keys()):
            data["hooks"][event] = [
                e for e in data["hooks"][event]
                if not _is_our_hook(e, repo_root)
            ]
            if not data["hooks"][event]:
                del data["hooks"][event]
        if not data["hooks"]:
            del data["hooks"]

    # ── permissions ──────────────────────────────────────────────────────────
    if "permissions" in data:
        if "allow" in data["permissions"]:
            data["permissions"]["allow"] = [
                a for a in data["permissions"]["allow"]
                if not _is_our_permission(a, repo_root)
            ]
            if not data["permissions"]["allow"]:
                del data["permissions"]["allow"]
        if not data["permissions"]:
            del data["permissions"]

    _save(settings_path, data)
    print("Removed brain-rot entries from {}.".format(settings_path))


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Add or remove brain-rot hook/permission entries in a Claude Code settings.json."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    add_p = sub.add_parser("add", help="Add brain-rot entries to settings.json")
    add_p.add_argument("--repo-root", required=True, help="Absolute path to the brain-rot repo")
    add_p.add_argument("--py-cmd", required=True, help="Python executable (python or python3)")
    add_p.add_argument("--settings", default=DEFAULT_SETTINGS,
                       help="Path to Claude Code settings.json (default: ~/.claude/settings.json)")

    rem_p = sub.add_parser("remove", help="Remove brain-rot entries from settings.json")
    rem_p.add_argument("--repo-root", required=True, help="Absolute path to the brain-rot repo")
    rem_p.add_argument("--settings", default=DEFAULT_SETTINGS,
                       help="Path to Claude Code settings.json (default: ~/.claude/settings.json)")

    args = parser.parse_args()

    try:
        if args.command == "add":
            cmd_add(args.repo_root, args.py_cmd, args.settings)
        elif args.command == "remove":
            cmd_remove(args.repo_root, args.settings)
    except Exception as exc:
        print("Error: {}".format(exc), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
