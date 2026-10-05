---
name: claude-code-authoring
description: Author and review Claude Code extensions against the live, current docs instead of stale training data or old bundled guides. Use when creating, editing, reviewing or debugging a Claude Code skill (SKILL.md, frontmatter, $ARGUMENTS, context fork), hook (settings.json hooks, hooks.json, exit codes, decision JSON), subagent (agents/*.md), plugin (plugin.json, marketplace, plugin layout, plugin validate or eval), mod (a plugin with a JS/TS hooks module: hooks.json "modules", register(on), on('tool.call'), ui.render panes or the band above the prompt, $.ui / $.command / $.tool / $.store, claude plugin test), output style, or Claude Code settings. Use it even when the request only mentions one field or event name, and whenever older guidance (plugin-dev, docs mirrors, "This skill should be used when...") is in play.
---

# Claude Code Authoring

Claude Code ships changes weekly. Your training data, the `plugin-dev` plugin, and
local docs mirrors all lag behind it: as of September 2026 `plugin-dev` knew 9 of 33
hook events and 3 skill frontmatter fields. So for anything you write or review
here, the live docs at `code.claude.com` are authoritative, and every file in this
skill is just a cache of them.

## Workflow

1. **Name the component.** Skill, hook, subagent, plugin/marketplace, mod, MCP
   config, output style, settings, or permissions. Each has one primary docs page
   (table below). "Hook" is ambiguous now: a mod's in-process JS handler or a
   settings hook (`command`/`http`/`prompt`/`agent`). Work out which one is meant
   before you write anything.

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
   wins; mention the drift to the user so the reference can be refreshed. For
   mods, one source outranks even the page: the `.d.ts` files Claude Code writes
   into `<mod>/.claude-plugin/types/` for the installed build. Grep
   `claude-code/index.d.ts` there for the exact event or method.

4. **Write it using current conventions** (below), then **validate** (below).

| Component | Page(s) (pass to `fetch_doc.sh`) | Quick reference |
|---|---|---|
| Skills | `skills` | `references/skills.md` |
| Hooks | `hooks` (reference), `hooks-guide` (tutorial) | `references/hooks.md` |
| Subagents | `sub-agents` | `references/subagents.md` |
| Plugins | `plugins/overview`, `plugins/manifest-reference`, `plugins/components`, `plugins/create-marketplace`, `plugins/dependencies`, `plugin-evals` | `references/plugins.md` |
| Mods | `plugins/mods/overview`, `create`, `reference`, `events`, `api`, `interface`, `gallery`, `test`, `troubleshoot`, `admin` (all under `plugins/mods/`) | `references/mods.md` |
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

### Mods (Claude Code 2.1.287+)

- **Pick a mod only when you need code inside Claude Code.** That means panes,
  the band above the prompt, restyling built-in UI, a `/command` that runs code
  with no Claude turn, or rewriting events. If a settings hook, skill, MCP
  server or status line already does the job, use that.
- **A mod is a plugin** whose `hooks/hooks.json` has
  `"modules": ["./register.js"]`. The ES module exports `register(on, options)`.
  There's no build step and no Node APIs; everything goes through `$`.
- **Write code the static analyzer can read.** Spell `$.ns.method(...)` in full
  with no aliasing or destructuring of `$`. Use string-literal event names, and
  imports only from relative paths or `claude-code`. Have at most one
  unfiltered `session.start` hook per module, and do command/tool registration
  there, last or inside try/catch.
- **Guards fail open.** A hook that throws or times out (10 s) is skipped. Add
  `.catch(...)` returning `{ deny }` / `{ refuse }` to fail closed, and still
  point users at permission rules for hard enforcement.
- **Module variables reset on every reload.** Use `$.state` for session values
  that drawings read, and `$.store` for values that persist across sessions.
- **Drawing shows only in the terminal and the Desktop Code tab.** Elsewhere
  (VS Code panel, `-p`, SDK, cloud), hooks run but nothing draws, so fall back
  to text. Some elements are terminal- or desktop-only.
- **When Claude Code's built-in `plugin-authoring` skill is available**, it
  covers the in-session hot-reload flow (`~/.claude/dev-mods/<session>/`). Use
  `references/mods.md` for standalone plugin directories, review, tests and
  shipping.

## Validate

- Plugins: `claude plugin validate <dir> --strict` for manifest and structure.
  Use `claude --plugin-dir <dir>` to load for one session, and `/reload-plugins`
  after edits to hooks, agents, MCP or output styles. Skill text reloads live.
- Behavior: `claude plugin eval init` scaffolds eval cases, and
  `claude plugin eval <dir-or-name>` runs them against a no-plugin baseline.
- Mods: `claude --plugin-dir <mod>` hot-reloads on save.
  `claude plugin validate <mod> --strict` must pass, and its `hooks:` /
  `calls:` lines must list every event and `$` call you meant to use.
  `claude plugin test <mod>` runs `*.test.ts` files that use
  `claude-code/testing`, with no session needed. `tsc -p <mod>` type-checks
  against the generated tsconfig. For installed mods, debug with
  `claude --debug-file <log>`.
- Standalone skills: the `skill-creator` skill's eval loop and description
  optimizer.
- Hooks: pipe a sample JSON payload into the script and check its exit code and
  stdout before wiring it into settings.

## Keeping this skill current

The references carry a "Verified" date. If it's more than ~60 days old, or you
hit drift, re-verify the affected tables against the live page and update both
the table and its date. Keep only facts that are stable and frequently needed
in the references; everything else stays a pointer to the live page.
