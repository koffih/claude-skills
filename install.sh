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
  install.sh --cron               install every skill now, then update them
                                  daily through this user's crontab
  install.sh --no-cron            remove that daily update

Skills go into ~/.claude/skills unless SKILLS_DIR is set.
USAGE
}

catalog() {
  # Local copy when run from a clone, the published copy otherwise.
  # When piped through bash there is no script file, hence the -f test:
  # otherwise a skills.tsv in the current directory would be picked up.
  local src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ] && [ -f "$src" ] && [ -r "$(dirname "$src")/skills.tsv" ]; then
    cat "$(dirname "$src")/skills.tsv"
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
  if ! script="$(curl -fsL "$url" 2>/dev/null)"; then
    echo "no skill named '$name' (expected github.com/$OWNER/$PREFIX$name). Try --list." >&2
    return 1
  fi
  echo "== $name"
  SKILLS_DIR="$BASE" bash -s -- "$@" <<<"$script"
}

# One crontab line per user, found again by this marker.
CRON_MARK="# koffih-claude-skills"

set_cron() {
  command -v crontab >/dev/null 2>&1 || { echo "crontab is not available on this machine." >&2; return 1; }
  local env="" minute=$((RANDOM % 60)) line
  [ -n "${SKILLS_DIR:-}" ] && env="SKILLS_DIR=$(printf %q "$SKILLS_DIR") "
  # A random minute spreads the servers over the hour. The log keeps the last run only.
  line="$minute 5 * * * curl -fsSL $RAW/install.sh | ${env}bash -s -- --all > \$HOME/.claude/koffih-skills-update.log 2>&1 $CRON_MARK"
  # Read the whole table before writing it back, never both in one pipeline.
  local current
  current="$(crontab -l 2>/dev/null | grep -vF "$CRON_MARK" || true)"
  { [ -n "$current" ] && printf '%s\n' "$current"; echo "$line"; } | crontab -
  echo "cron:      daily update at 05:$(printf %02d "$minute"), log in ~/.claude/koffih-skills-update.log"
}

unset_cron() {
  command -v crontab >/dev/null 2>&1 || { echo "no crontab on this machine, nothing to remove."; return 0; }
  if crontab -l 2>/dev/null | grep -qF "$CRON_MARK"; then
    local current
    current="$(crontab -l 2>/dev/null | grep -vF "$CRON_MARK" || true)"
    if [ -n "$current" ]; then printf '%s\n' "$current" | crontab -; else crontab -r; fi
    echo "cron:      daily update removed"
  else
    echo "cron:      no daily update was set"
  fi
}

NAMES=()
PASS=()
ACTION="install"

for arg in "$@"; do
  case "$arg" in
    --list)      ACTION="list" ;;
    --all)       ACTION="all" ;;
    --update)    ACTION="update" ;;
    --cron)      ACTION="cron" ;;
    --no-cron)   ACTION="no-cron" ;;
    --project)   BASE="$PWD/.claude/skills" ;;
    --uninstall) PASS+=("--uninstall") ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    *)           NAMES+=("$arg") ;;
  esac
done

command -v curl >/dev/null 2>&1 || { echo "curl is required but not installed." >&2; exit 1; }

case "$ACTION" in
  no-cron)
    unset_cron
    exit 0 ;;
  cron)
    if [ "$BASE" != "${SKILLS_DIR:-$HOME/.claude/skills}" ] || [ ${#NAMES[@]} -gt 0 ] || [ ${#PASS[@]} -gt 0 ]; then
      echo "--cron keeps every catalog skill up to date for this user: it takes no skill name, --project or --uninstall." >&2
      exit 2
    fi
    while IFS=$'\t' read -r name _; do
      [ -n "$name" ] && NAMES+=("$name")
    done < <(catalog) ;;
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
      # Read the file rather than running git in a folder another account may own.
      origin="$(git -C / config --file "$dir.git/config" --get remote.origin.url 2>/dev/null || true)"
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

if [ "$ACTION" = cron ]; then
  set_cron
fi

if [ "$failed" -gt 0 ]; then
  echo "$failed skill(s) failed." >&2
  exit 1
fi
