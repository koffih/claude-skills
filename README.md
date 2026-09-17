# koffih's Claude Code skills

Catalog of [Claude Code](https://claude.com/claude-code) skills published by koffih. Each skill lives in its own repository, installs on its own and is invoked on its own. This repository only lists them and installs them by name.

## Skills

| Skill | Invoke | What it does | Repository |
|---|---|---|---|
| autonomous-mode | `/autonomous-mode` | Extended autonomous work mode: inspects the project, then implements, tests and commits for hours, stopping only for irreversible decisions. | [claude-skill-autonomous-mode](https://github.com/koffih/claude-skill-autonomous-mode) |

All skill repositories are also findable through the [`claude-code-skill` topic](https://github.com/search?q=user%3Akoffih+topic%3Aclaude-code-skill&type=repositories).

## Install

One skill, straight from its own repository:

```bash
curl -fsSL https://raw.githubusercontent.com/koffih/claude-skill-<name>/main/install.sh | bash
```

Or by name through this catalog:

```bash
curl -fsSL https://raw.githubusercontent.com/koffih/claude-skills/main/install.sh | bash -s -- autonomous-mode
```

Catalog commands:

```bash
CAT=https://raw.githubusercontent.com/koffih/claude-skills/main/install.sh

curl -fsSL $CAT | bash -s -- --list                 # what is available
curl -fsSL $CAT | bash -s -- name-a name-b          # install or update some
curl -fsSL $CAT | bash -s -- --all                  # install or update all
curl -fsSL $CAT | bash -s -- --update               # update the ones already installed
curl -fsSL $CAT | bash -s -- name-a --project       # into ./.claude/skills
curl -fsSL $CAT | bash -s -- name-a --uninstall     # remove
```

Skills are git clones in `~/.claude/skills/<name>` (or `$SKILLS_DIR`), so updating is a fast-forward pull. Installers refuse to overwrite or delete a folder that is not a clone of the expected repository, and refuse to update a clone with local changes.

Requirements: `bash`, `git`, `curl`.

## Conventions for a new skill

Every skill follows the same shape, so any of them can be installed, found and maintained the same way.

- **Repository:** `koffih/claude-skill-<name>`, public, MIT, topics `claude-code-skill` and `agent-skill`.
- **Name:** `<name>` is lowercase kebab-case, identical in the repository suffix, the `name:` frontmatter field, the install folder and the slash command.
- **Language:** English.
- **Layout:**

  ```
  SKILL.md          frontmatter (name, description, optional argument-hint,
                    disable-model-invocation) and the instructions
  references/       detailed material Claude reads only when needed
  assets/           templates and files the skill produces or copies
  install.sh        install, update, --project, --uninstall; verifies after install
  README.md         what it does, install, use; links back to this catalog
  LICENSE
  ```

- **Description:** says what the skill does and when to use it; it is what decides whether Claude picks the skill.
- **`disable-model-invocation: true`** for any skill that grants broad permissions or has side effects, so it only runs when explicitly invoked.
- **No secrets**, ever: a skill names where a key lives, never its value.
- **Registering:** add a line to `skills.tsv` (`name<TAB>description`) and a row to the table above.

## License

MIT
