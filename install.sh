#!/bin/sh
# Installs the fable-orchestrator-workflow:
#   - the skill and its subagents into Claude Code
#   - `delegate` onto your PATH
# A file that already exists and differs is left alone unless you pass --force.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
claude=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
bin=${DELEGATE_BIN_DIR:-$HOME/.local/bin}
force=no
[ "${1:-}" = "--force" ] && force=yes

put() { # put <source> <destination>
    if [ -e "$2" ] && ! cmp -s "$1" "$2" && [ "$force" = no ]; then
        echo "kept       $2 (it differs; pass --force to replace it)"
        return 0
    fi
    if [ -e "$2" ] && cmp -s "$1" "$2"; then
        echo "unchanged  $2"
        return 0
    fi
    mkdir -p "$(dirname "$2")"
    cp -p "$1" "$2"
    echo "installed  $2"
}

skill=skills/fable-orchestrator-workflow
put "$here/$skill/SKILL.md"              "$claude/$skill/SKILL.md"
put "$here/$skill/scripts/delegate"      "$claude/$skill/scripts/delegate"
put "$here/$skill/templates/dossier.md"  "$claude/$skill/templates/dossier.md"
for agent in fable-judge opus-typist test-runner; do
    put "$here/agents/$agent.md" "$claude/agents/$agent.md"
done

target=$claude/$skill/scripts/delegate
chmod +x "$target"
mkdir -p "$bin"
if [ -e "$bin/delegate" ] || [ -L "$bin/delegate" ]; then
    if [ "$force" = no ] && [ "$(readlink "$bin/delegate" 2>/dev/null || true)" != "$target" ]; then
        echo "kept       $bin/delegate (already there; pass --force to point it here)"
    else
        ln -sfn "$target" "$bin/delegate"
        echo "linked     $bin/delegate -> $target"
    fi
else
    ln -s "$target" "$bin/delegate"
    echo "linked     $bin/delegate -> $target"
fi

echo
echo "Next: make sure $bin is on your PATH, then type /fable-orchestrator-workflow in Claude Code."
