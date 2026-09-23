---
name: claude-code-authoring
description: Author and review Claude Code extensions against the live, current docs instead of stale training data or old bundled guides. Use when creating, editing, reviewing or debugging a Claude Code skill (SKILL.md, frontmatter, $ARGUMENTS, context fork), hook (settings.json hooks, hooks.json, exit codes, decision JSON), subagent (agents/*.md), plugin (plugin.json, marketplace, plugin layout, plugin validate or eval), output style, or Claude Code settings. Use it even when the request only mentions one field or event name, and whenever older guidance (plugin-dev, docs mirrors, "This skill should be used when...") is in play.
---

# Claude Code Authoring

Claude Code ships changes weekly. Your training data, the `plugin-dev` plugin, and
local docs mirrors all lag behind it: as of September 2026 `plugin-dev` knew 9 of 33
hook events and 3 skill frontmatter fields. So for anything you write or review
here, the live docs at `code.claude.com` are authoritative, and every file in this
skill is just a cache of them.

## Workflow

1. **Name the component.** Skill, hook, subagent, plugin/marketplace, MCP config,
   output style, settings, or permissions. Each has one primary docs page (table
   below).

2. **Read the live page before writing.** Fetch the raw markdown, then grep it:

   ```bash
   f=$("${CLAUDE_SKILL_DIR}/scripts/fetch_doc.sh" hooks)   # prints cached path
   grep -n 'permissionDecision' "$f"
   ```

   Use the raw page rather than a summarizing fetch. Summaries paraphrase enum
   values: one reported PreToolUse `permissionDecision` as `allow|deny|skip`, but
   the real values are `allow|deny|ask|defer`. Grep for the exact field or event
   name you're about to write, and read the surrounding section. The pages are
   long (hooks.md is ~3,900 lines), so grep for headings (`grep -n '^#'`) and
   read the section you need rather than the whole file. Run `fetch_doc.sh --index`
   to list every page when the table below doesn't cover something.

3. **Use the quick references for orientation, not as the final word.** They were
   verified on the date in their header. If the live page disagrees, the page
   wins; mention the drift to the user so the reference can be refreshed.

4. **Write it using current conventions** (below), then **validate** (below).

| Component | Page(s) (pass to `fetch_doc.sh`) | Quick reference |
|---|---|---|
| Skills | `skills` | `references/skills.md` |
| Hooks | `hooks` (reference), `hooks-guide` (tutorial) | `references/hooks.md` |
| Subagents | `sub-agents` | `references/subagents.md` |
| Plugins | `plugins`, `plugins-reference`, `plugin-marketplaces`, `plugin-evals`, `plugin-dependencies` | `references/plugins.md` |
| Settings | `settings`, `settings-reference` | none; always read live |
| Permissions | `permissions`, `permission-modes` | none |
| MCP | `mcp` | none |
| Output styles | `output-styles` | none |
| Memory / CLAUDE.md | `memory` | none |
| Built-in commands | `commands` | none |
| Agent SDK | `agent-sdk/overview`, `agent-sdk/skills`, `agent-sdk/hooks`, ... | none |

## Current conventions that old guidance gets wrong

- **Skills replace commands.** `.claude/commands/x.md` still works, but new work
  goes in `skills/<name>/SKILL.md`. A plugin's `commands/` dir is legacy.
- **Descriptions say what, then "Use when...".** Put the key use case first. The
  listing truncates `description` + `when_to_use` at 1,536 characters combined.
  The old third-person "This skill should be used when the user asks..." pattern
  is outdated.
- **SKILL.md under 500 lines**, not a word budget. Move detail into sibling
  files and say when to read each one.
- **Reference bundled files with `${CLAUDE_SKILL_DIR}`** (the skill's own dir) or
  `${CLAUDE_PLUGIN_ROOT}` (plugin root). Put state that must survive plugin
  updates in `${CLAUDE_PLUGIN_DATA}`.
- **Control invocation with frontmatter**, not prose:
  `disable-model-invocation: true` for user-triggered side-effect workflows,
  `user-invocable: false` for background knowledge, `context: fork` + `agent` to
  run in a subagent, `allowed-tools` to pre-approve tools for that turn.
- **Plugin subagents ignore `hooks`, `mcpServers` and `permissionMode`.** Put those
  in the plugin's `hooks/hooks.json` / `.mcp.json` instead.
- **Hooks have five handler types** (`command`, `http`, `mcp_tool`, `prompt`,
  `agent`). Narrow tool hooks with the `if` field (permission-rule syntax), not
  only `matcher`. Treat `if` as best-effort, and use permission rules for hard
  allow or deny.
- **Blocking differs per event.** Exit 2 blocks only on events that can block,
  and the JSON decision field differs per event. Look up the event's "decision
  control" section every time.

## Validate

- Plugins: `claude plugin validate <dir> --strict` for manifest and structure.
  Use `claude --plugin-dir <dir>` to load for one session, and `/reload-plugins`
  after edits to hooks, agents, MCP or output styles. Skill text reloads live.
- Behavior: `claude plugin eval init` scaffolds eval cases, and
  `claude plugin eval <dir-or-name>` runs them against a no-plugin baseline.
- Standalone skills: the `skill-creator` skill's eval loop and description
  optimizer.
- Hooks: pipe a sample JSON payload into the script and check its exit code and
  stdout before wiring it into settings.

## Keeping this skill current

The references carry a "Verified" date. If it's more than ~60 days old, or you
hit drift, re-verify the affected tables against the live page and update both
the table and its date. Keep only facts that are stable and frequently needed
in the references; everything else stays a pointer to the live page.
