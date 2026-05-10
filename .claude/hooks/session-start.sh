#!/usr/bin/env bash
# Auto-install gstack skills into ~/.claude/skills/ for Claude Code on the web.
# Each web/mobile session starts in a fresh container, so the symlinks made by
# ./setup don't persist. This hook recreates them on every session start.
# Idempotent and non-interactive.
set -euo pipefail

# Only run in remote (web/mobile) Claude Code sessions. Local sessions should
# run ./setup once interactively and not pay this cost on every start.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR"

# 1. Point ~/.claude/skills/gstack at the repo so internal SKILL.md cross-refs
# (which use paths like gstack/<skill>/...) resolve.
ln -snf "$REPO" "$SKILLS_DIR/gstack"

# 2. For each repo subdirectory that has a SKILL.md, create a flat-name entry
# under ~/.claude/skills/<name>/SKILL.md so Claude Code discovers /qa, /ship,
# /review, /office-hours, etc. as top-level slash commands.
linked=0
for skill_dir in "$REPO"/*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  dir_name="$(basename "$skill_dir")"
  [ "$dir_name" = "node_modules" ] && continue
  [ "$dir_name" = ".claude" ] && continue

  # Use the frontmatter name: field if present, else fall back to dir name.
  skill_name=$(grep -m1 '^name:' "$skill_dir/SKILL.md" 2>/dev/null \
    | sed 's/^name:[[:space:]]*//' | tr -d '[:space:]')
  [ -z "$skill_name" ] && skill_name="$dir_name"

  target="$SKILLS_DIR/$skill_name"
  # Replace any pre-existing symlink with a real dir + symlinked SKILL.md
  # (Claude Code discovers skills as top-level dirs, not nested under gstack/).
  [ -L "$target" ] && rm -f "$target"
  mkdir -p "$target"
  ln -snf "$skill_dir/SKILL.md" "$target/SKILL.md"
  linked=$((linked + 1))
done

# Backwards-compat alias: /connect-chrome -> /open-gstack-browser
ln -snf "gstack/open-gstack-browser" "$SKILLS_DIR/connect-chrome"

echo "gstack: linked $linked skills into $SKILLS_DIR" >&2
