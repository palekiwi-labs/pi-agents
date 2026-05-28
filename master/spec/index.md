# Agents Extension — Feature Specification

## Context and Prerequisites

- Implementation roadmap: `.mem/master/spec/plan.md`
- Technical concept reference: `.mem/master/ref/ext-agents-concepts.md`
- Pi extension system reference: `.mem/master/ref/extensions-index.md`

---

## Overview

The `agents` extension adds a multi-persona framework to Pi. Users define named agent personas
in Markdown files. They can switch between personas interactively via keyboard shortcut.
When a message is submitted, the active persona is committed to the turn and its configuration
(system prompt, reminder text) is automatically injected into the agent context.

The extension is built in three phases:
- **Phase 1**: Primary agents — persona switching within the main session
- **Phase 2**: Sub-agents — spawned child sessions for delegated tasks
- **Phase 3**: Refinements — tool restriction, bash permissions, MCP access

---

## Extension Location

Development location: `.pi/extensions/agents/index.ts`

The `.pi/` directory sits in the Pi repository root, giving access to the codebase during
development. Future: may be extracted to a standalone package.

---

## Agent Definition Format

Agents are defined as Markdown files: `.pi/agents/*.md`

### Phase 1 Frontmatter Schema

```yaml
---
name: research
description: Focused on gathering and analyzing information
color: blue
reminder: You are in Research mode. Gather information only. Do not make changes.
---

Full system prompt body.
This is injected as invisible context when this persona is first activated
or when the user switches to this persona.
```

| Field | Required | Purpose |
|---|---|---|
| `name` | yes | Identifier used in UI and session entries |
| `description` | no | Shown in future picker UI |
| `color` | no | Accent color for status bar label |
| `reminder` | no | Short injected text on persona activation/change |
| body | no | Full system prompt; injected as invisible context message |

### Phase 2 Additional Fields

```yaml
model: anthropic/claude-3-5-sonnet  # model override for sub-agent runs
tools: read, bash, grep              # restricted tool list
context: fresh                       # fresh (default) or fork (inherits parent history)
max-steps: 20                        # tool-call iteration limit before forced return
```

---

## Primary Agent Behavior (Phase 1)

### Two-State Model

Two distinct runtime states must never be conflated:

| State | Description | When it changes |
|---|---|---|
| `activeAgent` | Selected in UI | Any time user cycles via shortcut |
| `committedAgent` | Snapshotted at message submission | Only when user submits a message |

The `committedAgent` governs all behavior within a running turn.
The user may change `activeAgent` freely mid-run without affecting the in-progress turn.

### Full Lifecycle

**1. Startup**
- Scan `.pi/agents/*.md`, parse all valid files
- Determine initial `activeAgent`:
  1. Configured default (settings key `defaultAgent` or CLI flag)
  2. First agent in loaded list (alphabetical)
  3. `null` if no agents defined (extension becomes a no-op)
- Restore `committedAgent` from the last `agent-commit` session entry (via `session_start` hook)
- Set status bar to reflect initial `activeAgent`

**2. User cycles agents** (keyboard shortcut)
- Advance `activeAgent` to next in list (wraps around)
- Update status bar immediately: `ctx.ui.setStatus("agent", name)` with agent color
- No session write — this is ephemeral UI state only

**3. User submits a message** (`input` event)
- Snapshot: `committedAgent = activeAgent`
- Persist: `pi.appendEntry("agent-commit", { name: committedAgent.name })`

**4. Agent turn begins** (`before_agent_start` event)
- Read `lastCommittedAgent` from the session branch (the `agent-commit` entry prior to the current turn)
- Decision:
  - If **first message** of session OR **persona changed**: inject context message
  - If **same persona as last turn**: inject nothing (LLM retains context from conversation history)

**5. Context injection** (when triggered)
- Returns from `before_agent_start` handler:
  ```
  [AGENT: Research]
  <body of research.md>
  Reminder: <reminder field>
  ```
- Injected with `display: false` — invisible to the user in the TUI

**6. Session reload** (`session_start` event)
- Scan the current session branch for `agent-commit` entries
- Restore `activeAgent` and `committedAgent` from the most recent entry

### Default / No-Op Behavior

- If no agents are loaded: extension is entirely passive — no status bar, no injection
- If an agent has no `reminder` and no body: no injection occurs but the agent is still selectable

---

## Sub-Agent Behavior (Phase 2 — outline only)

Sub-agents are spawned as child `pi` processes with isolated, discarded sessions.

### Invocation

A `delegate` tool is registered. The LLM calls it with:
- `agent`: name matching a `.pi/agents/*.md` file
- `task`: task description string

### Spawn Command

```
pi --no-session --mode json --append-system-prompt <tmpfile> [--tools <list>] [--model <name>]
```

Reference implementation: `packages/coding-agent/examples/extensions/subagent/index.ts`

### Budget Enforcement

- Track tool-call iterations in real time from the subprocess JSON stream
- When `max-steps` threshold is reached: kill process, return a forced summary to parent
- Prevents runaway sub-agents (reference: opencode's `steps` limit concept)

### Context Modes

- `context: fresh` (default): sub-agent starts with no parent history
- `context: fork`: parent conversation history is passed to sub-agent

### Output

- Sub-agent final text returned as tool result content
- Sub-session discarded on completion
- Output capped at ~50KB to protect parent context window

---

## Phase 3 Refinements (outline only)

- `tools` frontmatter for primary agents: applied via `pi.setActiveTools()` at turn start,
  restored at turn end to avoid global state bleed
- `bash-allow` / `bash-deny` lists: enforced via `tool_call` hook with pattern matching
- MCP tool access: `mcp:tool-name` syntax in `tools` frontmatter, maps to mcp-adapter conventions
- Background sub-agent execution with TUI progress widget
- Agent picker modal via `ctx.ui.select()`
