# Mods quick reference

Verified against https://code.claude.com/docs/en/plugins/mods/*.md (written for
Claude Code v2.1.289) on 2026-10-05, and checked with `claude plugin validate` /
`claude plugin test` on 2.1.289. Mods need v2.1.287+. Precedence when sources
disagree: the `.d.ts` files Claude Code writes for the running build, then the
live page, then this file.

## What a mod is, and when to pick one

A mod is a plugin whose `hooks/hooks.json` has a `modules` key. That key points
at a JS/TS **hooks module**, and Claude Code calls its functions in its own
process. The functions can observe, rewrite or answer events such as tool calls,
prompts, turns and UI renders, and they can call the mods API (`$`).

**Terminology trap:** the mods docs say "hook" for a mod's handler and "settings
hook" for the `command`/`http`/`prompt`/`agent` kind in `settings.json` or
`hooks.json` `hooks`. When someone says "hook", check which one they mean.

| Pick | When |
|---|---|
| Mod | A pane, a band above the prompt, restyling built-in UI, a `/command` that runs code with no Claude turn, rewriting an event, or sharing state between handlers |
| Settings hook | Block/allow/log an event with a script you already have |
| Skill | Instructions Claude should follow |
| MCP server | Claude needs tools that reach an external system |
| Status line | A one-line shell-script status. A mod can do it too, but it's heavier. |

One plugin can ship all of these together.

## Layout

```
my-mod/
├── .claude-plugin/plugin.json   # no extra required fields; optional "types": "./types/index.d.ts"
├── hooks/
│   ├── hooks.json               # {"modules": ["./register.js"]}  (exactly one path, relative to hooks.json)
│   └── register.js              # the hooks module
├── types/index.d.ts             # needed when using $.state or adding an API namespace
└── tests/*.test.ts              # run by `claude plugin test`
```

- `hooks.json` may also hold settings hooks under `hooks`. If `modules` is
  missing or misspelled, `validate` passes but prints no `hooks:` line.
- The module can be `.js .mjs .cjs .jsx .ts .mts .cts .tsx`, and it must be an
  ES module. There's no build step and no Node.js: no `require`, `fs`,
  `setTimeout` or `process`. Web APIs (`URL`, `TextEncoder`, `AbortController`,
  `crypto.subtle`) are available. Everything else goes through `$`.
- Name rules: don't start the name with `claude-` (validate rejects it).
  Command, tool, agent and pane names use `[A-Za-z0-9_-]`, max 64 characters.

## The hooks module

```js
let calls = 0                                   // module state: resets on every reload

export function register(on, options) {         // options = userConfig values, defaults filled
  on('session.start', async ($, e, next) => {   // ONE unfiltered session.start per module
    await $.command.register({ name: 'tally', description: 'Show tool-call count' })
    return next(e)                              // observe
  })
  on('tool.call', async ($, e, next) => {
    calls += 1
    $.ui.invalidate('ui.render')
    return next(e)
  })
  on('command.run', { command: 'tally' }, async () => ({ text: `${calls} tool calls` }))  // answer
  on('ui.render', { component: 'Spinner' }, async ($, e, next) =>
    next({ ...e, props: { ...e.props, suffix: ` · ${calls} calls…` } }))                   // rewrite
}
```

- **`e`** is deeply frozen. To rewrite it, pass a copy: `next({ ...e, text })`.
- **`next(e)`** is middleware. It runs the later mods and then Claude Code, and
  resolves to the result. Use `await next(e)` to act after the event.
- To **answer**, return a result object without calling `next`. Later mods and
  Claude Code don't run, and for `tool.call` there's no permission prompt either.
- **`next.signal`** (AbortSignal), **`next.origin`** `{plugin, tier}`,
  **`next.budget`** `{ms, remainingMs}`, and **`next.to(e, tier)`** (only for
  prepend/append mods).
- `turn.step` and `process.spawn` hooks are **async generators**:
  `async function* ($, e, next) { const r = yield* next(e); return r }`.
- **`on(...).catch(handler)`** runs when the hook throws or times out. In the
  handler, `next.error.kind` is `throw` or `timeout`. Without `.catch`, a failed
  hook is **skipped**, so a guard fails open.

**Matchers** (2nd arg to `on`): every field must match. A field can be a value,
an array of values, or a RegExp: `{ tool: /^mcp__github__/ }`. Wildcards: `'*'`
(every event except telemetry) and `'classic.*'`. Telemetry hooks need
`{ to: 'collector' }`. Registering the same event twice with no matcher fails to
load.

## Static-analysis rules (`validate` and the loader enforce them)

- Write every API call in full, as `$.ns.method(...)`. No `const ui = $.ui`, no
  destructuring, no computed names. Passing `$` to a **top-level function** in
  the same file is fine (`calls:` shows `(via fn)`). Passing it to a method, an
  inner function or an imported function fails.
- Event names in `on(...)` must be string literals, so no variables and no
  loops. Don't redeclare `on` inside `register`.
- Imports: relative paths inside the plugin, plus `claude-code` (types and the
  `atom`/`read`/`update` state helpers). No dynamic `import()`.
- `$.env.get/set` names and `atom({ plugin, key })` args must be string literals.

## Events (what a hook can return)

| Group | Events → returns |
|---|---|
| Tools | `tool.call` → `next(e)` / `{ deny }` / `{ result }`; `tool.check` (after rules + PreToolUse) → `{ decision: allow\|ask\|deny, reason }`; `tool.describe` → `{ description, isDeferred }` |
| Prompts | `prompt.submit` → `next({...e, text})` / `next({...e, context: [...]})` / `{ drop }`; `prompt.fill`, `prompt.suggest`, `prompt.edit`; `prompt.compose` → `{ sections }`; `prompt.section` → `{ text }` or `{ text: null }`; `prompt.context` → `{ blocks }`; `prompt.attachment`; `skill.prompt` → `{ text }`; `attribution.text` |
| Commands/config | `command.run` → `{ text }` / `{}`; `command.describe`; `config.set` → `{ deny }`; `config.describe` |
| Turns | `turn.start`; `turn.step` (generator; `next({...e, model})` / `effort`); `turn.complete` → `{ text }` line under the answer |
| Session | `session.start` (per mod load/reload, **not** after `/clear`/`/resume`/`/branch`); `session.end`; `session.compact` → `{ skip }`; `session.receive` → `{ consumed }`; `session.send`; `session.append`; `session.attach/detach`; `session.measure` |
| Subagents | `agent.offer` → `{ isOffered: false }`; `agent.spawn` → `next({...e, model})` / `{ deny }` |
| UI | `ui.render`, `ui.resolve`, `ui.press`, `ui.input`, `ui.select`, `ui.focus`, `ui.scroll`, `ui.close`, `ui.message`, `ui.fault` |
| Other mods | `plugin.register` → `{ refuse }`; `engine.create` |
| Settings-hook events | `classic.<Event>` (e.g. `classic.Stop`, `classic.SessionStart`); `e` is that hook's stdin JSON |
| API calls | Every `$` method is also an event (`fs.read`, `model.complete`, ...) → `next(e)` / `{ deny }` / `{ value }` |

## Mods API (`$`)

`$.plugin` (name, root) · `$.ui` (resolve, invalidate, open, close, panes,
focus, scroll, toast, status, log, notice, ask, copy, selection, blit) ·
`$.command` (register, run, list) · `$.tool` (register, call, check, list) ·
`$.agent` · `$.model` (complete, fork, classify) · `$.prompt` (submit, read,
fill, suggest, compose) · `$.turn.abort` · `$.session` (messages, cwd, model,
usage, id, send, ...) · `$.config` · `$.settings.read` · `$.env` · `$.fs` (read,
write, list, exists, stat, ancestors) · `$.store` · `$.state` · `$.clock` (now,
sleep, after, every) · `$.http.fetch` · `$.process` (run, spawn) · `$.mcp` (call,
connect) · `$.audio` · `$.telemetry`.

Facts that trip people up:
- **Register commands and tools in `session.start`.** `$.command.register`
  throws when the name is taken (a built-in, for example), and the skipped hook
  loses everything after the throw. Register last, or wrap the call in try/catch.
  `immediate: true` lets a command run mid-turn. Return `{}` to print nothing.
- **Tools:** `$.tool.register({ name, description, inputSchema })`. Claude sees
  the tool as `mcp__<plugin>__<name>`, so match exactly that in `tool.call` and
  return `{ result }`.
- **`$.model.complete({ model, system, prompt, maxTokens, timeoutMs })`** doesn't
  reject on an API failure. Check `r.isAnswered`, then read `r.text` or
  `r.reason`. `$.model.fork` asks about the current conversation and hits the
  prompt cache. Both spend the user's quota.
- **`$.process.run(argv)`** runs with no shell. It resolves
  `{ exitCode, stdout, stderr }` and rejects if the program won't start or times
  out (default 30 s). **`$.http.fetch`** resolves
  `{ status, ok, headers, text }`. Relative paths resolve against the session
  cwd.
- **`$.ui.status`**: a sticky line under the prompt. **`$.ui.toast`**: shown for
  4 s. **`$.ui.log(text)`**: a dim transcript line Claude doesn't read.
  **`$.ui.log(text, { to: 'debug' })`**: goes to the debug log.
- **`$.ui.ask(question, options)`** holds a tool call for the user's answer. It
  rejects when dismissed and in `-p`, so default to the safe answer.
- **`$.prompt.submit({ text })`** starts a turn once the session is idle. Add
  `asUser: true` to send it as the user's words. Don't await it mid-turn.
- **Background work:** `$.clock.every(ms, fn)` / `$.clock.after(ms, fn)`, started
  in `session.start`. Timers stop on reload.

## Drawing

- `on('ui.render', { component: 'Pane' | 'AbovePrompt' | ... }, ...)`, then
  `const { Box, Text, Button } = $.ui.resolve(e)` and return a tree.
  `next(e)` = draw nothing (band) or Claude Code's own drawing (built-in sites).
  To keep other mods' band content, put `await next(e)` inside your `Box`.
- **Pane:** `await $.ui.open({ id, title, focus: true, closeOnEscape: true, rows, columns })`.
  In `ui.render`, check `e.requestId === id`. The boolean options accept only
  `true`: omit them, because `false` throws. A pane opened without a user action
  appears only at ≥144 columns (≥110 once the user has opened it); check
  `isPlaced`.
- **Built-in sites you can restyle or replace:** `UserMessage`,
  `AssistantMessage`, `ToolUse`, `ToolResult`, `ToolGroup`, `CommandOutput`,
  `AskUserQuestion` (keep the `next` ref exactly once), `Spinner`, `SessionMode`,
  `PromptHint`. Terminal only: `ToolProgress`, `TurnDuration`, `InfoNotice`. The
  permission prompt can't be changed.
- **Elements:** `Box`, `Text`, `Button` (`key`, `label`, `onPress`, `hotkey`,
  `plain`), `Link`, `Code`, `Markdown` (`text` prop), `Input`, `Select`,
  `Client`. `Raster` and `Image` are terminal-only, and `Svg` is desktop-only, so
  branch on `e.surface`. An invalid prop or element means Claude Code draws its
  own version (`ui.render (Pane) refused: ...`).
- Fit width to `e.props.bodyColumns`. Redraw with `$.ui.invalidate('ui.render')`
  (throttled to 10/s, or 30/s for visible terminal sites). Claude Code never
  redraws on its own when your variables change.
- **Where drawing shows:** terminal and the Desktop Code tab only. Hooks still
  run in the VS Code panel, `claude -p`/Agent SDK and cloud sessions, so fall
  back to `{ text }`. Mods don't run in WSL Desktop sessions.

## State

| Where | Lasts until | Use for |
|---|---|---|
| Module variable | The next reload (every save in dev) | Throwaway UI state |
| `$.state` (`atom`/`read`/`update` from `claude-code`) | Session end or `/clear`/`/resume`/`/branch`; survives reloads; auto-redraws readers | Values a drawing depends on |
| `$.store` (get/set/delete/keys) | Deleted, or idle for `cleanupPeriodDays`; shared by every session on the machine; 4 MiB | Settings, history |

`$.state` needs `types/index.d.ts` declaring
`interface PluginState { '<plugin>': {...} }` inside `declare module 'claude-code'`,
plus `"types"` in plugin.json. A `ui.render` hook can read state but not write
it. To re-load from `$.store` after `/clear`, use
`on('classic.SessionStart', { source: ['clear','resume','fork'] }, ...)`.
`$.store` get-then-set isn't atomic across sessions, so use one key per item and
re-`get` right before you `set`. `$.fs.write` isn't atomic either.

## Order, safety, policy

- **Chain order:** `sec-default@builtin` guard / `prependPlugins` / other org
  mods → user-installed mods (a mod runs before its `dependencies`) →
  `appendPlugins` → other built-ins. Within a module, hooks run in `on` order.
- **Managed `PreToolUse` hooks** run before any mod's `tool.call`, and their
  block is final. Other `PreToolUse` hooks run inside the last `next`.
  `tool.check` sees the decision from rules + hooks and can override it (except
  a managed block, or a deny rule unless `allowModsToOverrideDenyRules`).
- A regex guard on `e.command` is a reminder for Claude, not enforcement. For
  hard limits use permission rules, branch protection or managed settings.
- Mods aren't sandboxed. They run as the user, and the Bash sandbox doesn't
  cover processes a mod starts.
- **Admin settings:** `allowManagedModsOnly`, `allowModsToOverrideDenyRules`
  (built-in guard options), `prependPlugins`/`appendPlugins`,
  `allowManagedHooksOnly`, `disableAllHooks`, `disableSideloadFlags`,
  `pluginConfigs` (userConfig values; `<name>@inline` for `--plugin-dir`).
  `--safe-mode` and `--bare` stop installed mods but not built-ins.

## Limits

Hook run time: 10 s (`prompt.edit` 50 ms). Time awaiting `next` or `$` calls
doesn't count, except `$.clock.sleep`. A timed-out hook is skipped. `.catch`
handler: 1 s. All `session.end` hooks: the SessionEnd budget (1.5 s).
`$.process.run`: 30 s default, 10 min max. `$.model.complete` `maxTokens`:
1024 default. `$.fs` read/write: 4 MiB per file. `$.store`: 4 MiB total.
`Text` string child: 10,000 chars. `$.session.messages()`: newest 4,096.
One test: 5 s.

## Dev loop

1. **Scaffold or edit with hot reload.** `claude --plugin-dir ./my-mod` reloads
   on save and prints a transcript line per reload. A broken save keeps the
   previous version running. The built-in `/plugin-authoring` skill writes
   session mods to `~/.claude/dev-mods/<session-id>/<mod>/`, and they load after
   the user approves hot reload. Copy one out to keep it, because that folder is
   cleaned up.
2. **Types.** Each load writes `<mod>/.claude-plugin/types/` (`claude-code/`,
   `claude-code-tools/`, `claude-code-mcp/`, `tsconfig.json`) and a root
   `tsconfig.json` if there isn't one. Grep
   `.claude-plugin/types/claude-code/index.d.ts` for an event or method before
   using it. `claude -p "/<cmd>" --plugin-dir ./my-mod` is a quick way to get
   them written. Type-check with `tsc -p ./my-mod`.
3. **Static check.** `claude plugin validate ./my-mod --strict`. Read the
   `hooks:` and `calls:` lines (plus `env reads:`/`state reads:`). A missing
   event means a typo or a missing `modules`.
4. **Tests.** `claude plugin test [dir]` runs `*.test.ts(x)`:
   ```ts
   import { expect, test, mock } from 'claude-code/testing'
   test('denies force push', async ($, on) => {        // for a Bash tool.call guard mod
     on('tool.call', () => ({ result: 'ran' }))          // stub Claude Code; register stubs before the first $ call
     const r = await $.tool.call({ tool: 'Bash', command: 'git push -f' })
     expect(r.deny).toBeDefined()
   })
   ```
   A stub for a `$` call returns `{ value }` (or `{ deny }`), and a stub for an
   event returns that event's result. `session.start` doesn't fire on its own:
   fire `$.session.start({...})` and stub `command.register`. Use
   `mock.clock(on)`, `mock.store(on, {...})` and `mock.env(on, {...})`. If a
   `ui.render` hook returns `next(e)`, it needs a `ui.render` stub. Read the
   `test` page before testing drawings.
5. **Debug.** Installed mods only log to `claude --debug-file ./x.log`. Grep
   for `hooks module <name>`, `hook skipped`, `refused`. Under `--plugin-dir`,
   these show as dim transcript lines. `/plugin` shows `N mod active · names`.
   The `troubleshoot` page maps each message to its cause.
6. **Ship.** Bump `version`, then publish through a marketplace. Develop against
   the directory, because installed copies are cached by version. State the
   Claude Code version you tested in the README.

## Examples to read

- Built-in mod source: https://github.com/anthropics/claude-code/tree/main/mods
  (`diff`, `agents-md`, `sec-default`, `telemetry`), with tests.
- Samples: https://github.com/anthropics/claude-code-playground/tree/main/claude-code/mods
  (`token-weather`, `blast-radius`, `replay-theater`).
