# authoring-kit

Skills for building Claude Code extensions against the **live** docs at
[code.claude.com](https://code.claude.com/docs), not stale training data or
bundled guides.

Claude Code changes weekly. As of September 2026, Anthropic's `plugin-dev`
plugin documented 9 of 33 hook events and 3 of ~20 skill frontmatter fields.
This kit treats the docs as the source of truth and keeps only a small, dated
cache of the facts you need most.

## Skills

| Skill | What it does |
|---|---|
| `claude-code-authoring` | Workflow + dated quick references for skills, hooks, subagents, plugins and mods. Fetches raw doc pages (`scripts/fetch_doc.sh`) so field names and enum values are exact. |

Mods are plugins that run JS/TS hooks inside Claude Code and can draw panes,
add commands, or rewrite tool calls. They need Claude Code v2.1.287 or later. Mod
guidance lives in `references/mods.md`, which also covers the generated `.d.ts`
types, `claude plugin validate` and `claude plugin test`.

## Install

As a plugin (once listed in `kha-marketplace`):

```bash
claude plugin install authoring-kit@kha-marketplace
```

Try it from a local checkout without installing:

```bash
claude --plugin-dir .
```

Or copy just the skill into your personal skills:

```bash
cp -R skills/claude-code-authoring ~/.claude/skills/
```

## Name change

This plugin was previously named `claude-code-dev-kit`. That name is on
Anthropic's reserved list — any plugin name starting with `claude-` is rejected
by `claude plugin validate` — so the catalog entry could never be installed. It
is now `authoring-kit`. The repository URL is unchanged, and the shipped skill
is still named `claude-code-authoring`.

## Keeping it current

Each file in `skills/claude-code-authoring/references/` has a "Verified" date.
Re-check it against the live page every ~60 days or whenever drift turns up,
and bump the plugin version.

Evals live in `skills/claude-code-authoring/evals/evals.json`. They use the
skill-creator eval format.

## License

MIT
