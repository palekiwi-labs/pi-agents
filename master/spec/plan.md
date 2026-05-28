# Agents Extension — Implementation Plan

## Context

- Feature specification: `.mem/master/spec/index.md`
- Technical concepts: `.mem/master/ref/ext-agents-concepts.md`

---

## Phase 1: Primary Agents

Goal: users can define personas in `.pi/agents/*.md`, cycle between them via keyboard,
and have the active persona injected automatically when messages are submitted.

---

### Step 1.1 — Scaffold

**What to build:**
- Create `.pi/extensions/agents/index.ts` with an empty factory function
- Fire `ctx.ui.notify("Agents extension loaded", "info")` on startup to confirm loading

**Test:**
- Start Pi
- Confirm the notification appears
- Confirm Pi does not error or fail to start

---

### Step 1.2 — Agent File Discovery and Parsing

**What to build:**
- In the factory function (or `resources_discover` hook), scan `.pi/agents/*.md`
- Parse YAML frontmatter: `name`, `description`, `color`, `reminder`
- Parse the Markdown body as the system prompt text
- Store parsed agents in an in-memory list
- Notify how many agents were loaded (e.g. "Agents: loaded 3 personas")

**Test:**
- Create 2–3 `.md` files in `.pi/agents/` with different names and colors
- Confirm each is parsed correctly (log names to notification or console)
- Confirm a file with missing `name` is skipped gracefully

---

### Step 1.3 — Keyboard Cycling and Status Bar

**What to build:**
- Determine initial `activeAgent` (configured default → first in list → null)
- Register a keyboard shortcut via `pi.registerShortcut()` (key TBD, e.g. `ctrl+j`)
- Shortcut handler: advance `activeAgent` to next in list, wrap around to first after last
- On activation: `ctx.ui.setStatus("agent", activeAgent.name)` with color if defined
- On no agents loaded: do not set status, shortcut is a no-op

**Test:**
- Press shortcut repeatedly
- Confirm status bar cycles through agent names
- Confirm cycling wraps around after the last agent
- Confirm nothing breaks if only one agent is defined

---

### Step 1.4 — Turn Commitment, Persistence, and Injection

**What to build:**

`input` event handler:
- `committedAgent = activeAgent`
- `pi.appendEntry("agent-commit", { name: committedAgent.name })`

`before_agent_start` event handler:
- Scan `ctx.sessionManager.getBranch()` for prior `agent-commit` entries
- Determine `lastCommittedAgent` (the entry before the current pending commit)
- If first message of session OR `committedAgent.name !== lastCommittedAgent.name`:
  - Return `{ message: { content: buildInjectionText(committedAgent), display: false } }`
- Otherwise: return nothing

`session_start` event handler:
- Scan session branch for `agent-commit` entries
- Restore `activeAgent` and `committedAgent` from the most recent entry
- Update status bar to reflect restored agent

Helper `buildInjectionText(agent)`:
```
[AGENT: <name>]
<body>
Reminder: <reminder>
```
Omit sections that are empty.

**Test:**
- Start with "Research" agent active, submit a message
- Inspect session JSONL: confirm `agent-commit` entry is present
- Verify the injected message appears in the agent's context (check with `--mode json` or session file)
- Switch to "Plan" agent, submit another message — confirm new injection fires
- Submit a third message without switching — confirm no injection
- Reload Pi mid-session — confirm `activeAgent` is restored from session

---

## Phase 2: Sub-Agents

Goal: the LLM can delegate tasks to named sub-agents via a `delegate` tool.
Sub-agents run in isolated child processes and return results to the parent.

### Step 2.1 — Delegate Tool (basic)
- Register a `delegate` tool with params: `agent` (string), `task` (string)
- Spawn `pi --no-session --mode json` subprocess
- Pass agent's system prompt via `--append-system-prompt <tmpfile>`
- Stream JSON output, capture final assistant message
- Return as tool result

### Step 2.2 — Budget Enforcement
- Track tool-call iterations from subprocess JSON stream
- Kill process and return forced summary when `max-steps` reached

### Step 2.3 — Context Modes
- Support `context: fresh` (default) and `context: fork`
- For `fork`: serialize relevant parent context into the task prompt

### Step 2.4 — Tool Restriction
- Pass `--tools <list>` to subprocess based on `tools` frontmatter

---

## Phase 3: Refinements

Goal: add tool restriction, bash permissions, and MCP access to primary agents.

### Step 3.1 — Tool Restriction for Primary Agents
- Read `tools` frontmatter
- On `input` commit: call `pi.setActiveTools([...agentTools])`
- On `agent_end`: restore prior tool list
- Guard: snapshot active tools before changing, always restore

### Step 3.2 — Bash Permissions
- Read `bash-allow` and `bash-deny` lists from frontmatter
- Register `tool_call` hook for the `bash` tool
- Validate command against allow/deny patterns
- On deny: return error result without executing

### Step 3.3 — MCP Tool Access
- Support `mcp:tool-name` syntax in `tools` frontmatter
- Maps to the direct-tool naming convention from `pi-mcp-adapter`

### Step 3.4 — UX Improvements
- Agent picker modal via `ctx.ui.select()` (alternative to keyboard cycling)
- Background sub-agent TUI progress widget
