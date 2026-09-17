#!/usr/bin/env bash
# Install koffih's Claude Code skills by name. Each skill lives in its own
# repository, koffih/claude-skill-<name>, and ships its own install.sh: this
# script only finds it and runs it, so every skill stays installable alone.
set -euo pipefail

OWNER="koffih"
PREFIX="claude-skill-"
RAW="https://raw.githubusercontent.com/$OWNER/claude-skills/main"
BASE="${SKILLS_DIR:-$HOME/.claude/skills}"

usage() {
  cat <<USAGE
Install koffih's Claude Code skills by name.

  install.sh <name> [<name>...]   install or update these skills
  install.sh --all                install or update every skill in the catalog
  install.sh --update             update every koffih skill already installed
  install.sh --list               list the skills in the catalog
  install.sh <name> --project     install into ./.claude/skills instead
  install.sh <name> --uninstall   remove these skills

Skills go into ~/.claude/skills unless SKILLS_DIR is set.
USAGE
}

catalog() {
  # Local copy when run from a clone, the published copy otherwise.
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  if [ -n "$here" ] && [ -r "$here/skills.tsv" ]; then
    cat "$here/skills.tsv"
  else
    curl -fsSL "$RAW/skills.tsv"
  fi
}

run_skill_installer() {
  local name="$1"; shift
  case "$name" in
    *[!a-z0-9-]*|"") echo "invalid skill name: '$name'" >&2; return 1 ;;
  esac
  local url="https://raw.githubusercontent.com/$OWNER/$PREFIX$name/main/install.sh"
  local script
  if ! script="$(curl -fsSL "$url")"; then
    echo "no skill named '$name' (expected github.com/$OWNER/$PREFIX$name). Try --list." >&2
    return 1
  fi
  echo "== $name"
  SKILLS_DIR="$BASE" bash -s -- "$@" <<<"$script"
}

NAMES=()
PASS=()
ACTION="install"

for arg in "$@"; do
  case "$arg" in
    --list)      ACTION="list" ;;
    --all)       ACTION="all" ;;
    --update)    ACTION="update" ;;
    --project)   BASE="$PWD/.claude/skills" ;;
    --uninstall) PASS+=("--uninstall") ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    *)           NAMES+=("$arg") ;;
  esac
done

command -v curl >/dev/null 2>&1 || { echo "curl is required but not installed." >&2; exit 1; }

case "$ACTION" in
  list)
    catalog | awk -F'\t' 'NF >= 2 { printf "  %-24s %s\n", $1, $2 }'
    exit 0 ;;
  all)
    while IFS=$'\t' read -r name _; do
      [ -n "$name" ] && NAMES+=("$name")
    done < <(catalog) ;;
  update)
    # Every clone of a koffih/claude-skill-* repository in the skills folder.
    for dir in "$BASE"/*/; do
      [ -d "$dir.git" ] || continue
      origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
      case "$origin" in
        *github.com[:/]$OWNER/$PREFIX*) NAMES+=("$(basename "${origin%.git}" | sed "s/^$PREFIX//")") ;;
      esac
    done
    [ ${#NAMES[@]} -gt 0 ] || { echo "no koffih skill installed in $BASE"; exit 0; } ;;
esac

if [ ${#NAMES[@]} -eq 0 ]; then
  usage
  exit 2
fi

failed=0
for name in "${NAMES[@]}"; do
  run_skill_installer "$name" ${PASS[@]+"${PASS[@]}"} || failed=$((failed + 1))
done

if [ "$failed" -gt 0 ]; then
  echo "$failed skill(s) failed." >&2
  exit 1
fi
