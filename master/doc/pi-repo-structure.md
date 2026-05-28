# pi — Repository Structure

## Purpose

`pi` is a monorepo containing a full stack for building and running autonomous AI agents. The flagship application is an interactive, self-extensible coding assistant that can execute shell commands, edit files, and reason over codebases using large language models.

---

## Top-Level Layout

```
pi/
├── packages/
│   ├── ai/               # Foundational LLM abstraction layer
│   ├── agent/            # Generic agent runtime
│   ├── coding-agent/     # CLI coding assistant application
│   └── tui/              # Terminal UI library
├── scripts/              # Build, supply-chain, and tooling scripts
└── README.md
```

---

## Package Descriptions

### `packages/ai` — `@earendil-works/pi-ai`

The foundational layer. Provides a unified, multi-provider LLM API abstracting over OpenAI, Anthropic, Google, and Amazon Bedrock. Handles model registration, streaming, and provider-specific message transformations.

Key files:
- `src/api-registry.ts` — provider and model registration
- `src/models.ts` — model definitions and capabilities

### `packages/agent` — `@earendil-works/pi-agent-core`

The generic agent runtime layer. Implements the agent loop (reasoning, tool calling, message management) and the harness pattern for environment isolation.

Key files:
- `src/agent.ts` — top-level agent API
- `src/agent-loop.ts` — core reasoning and tool-call loop
- `src/harness/agent-harness.ts` — environment/session orchestrator
- `src/harness/types.ts` — `ExecutionEnv` interface (`FileSystem + Shell`)
- `src/harness/session/session.ts` — session persistence and context management

### `packages/coding-agent` — `@earendil-works/pi-coding-agent`

The application layer. An interactive CLI coding assistant built on the agent runtime. Ships with built-in tools (bash, read, write, grep) and supports interactive TUI, print, and RPC operation modes.

Key files:
- `src/main.ts` — CLI entry point
- `src/core/tools/` — built-in tool implementations

### `packages/tui` — `@earendil-works/pi-tui`

A custom terminal UI library used by the coding agent. Features differential rendering and a component-based structure for responsive terminal interfaces.

---

## Architectural Patterns

### Strict Layered Dependencies

Dependencies flow in one direction:

```
coding-agent  →  agent  →  ai
```

This ensures the LLM abstraction is fully decoupled from agent logic, and agent logic is decoupled from application-specific tools.

### Harness Pattern (Environment Isolation)

The `AgentHarness` class wraps the core agent loop and isolates it from the environment and session management. Key elements:

- **`ExecutionEnv`**: Interface combining `FileSystem` and `Shell`, injected into the harness. The loop never accesses the host system directly.
- **`Session`**: Manages the persistent conversation tree (history, branching, compaction). The harness snapshots session state at the start of each turn and injects it as context.
- **Hook system**: Middleware-like hooks allow context transformation, tool filtering, and auth injection without modifying the core loop.
- **Deferred writes**: Session mutations are queued during turns and flushed at "save points" (e.g., `turn_end`), ensuring consistency.

### Tool/Skill System

Agent capabilities are composed from:
- **Tools**: Discrete executable functions (bash, read, write, grep, etc.) registered with the harness.
- **Skills**: Modular instruction sets that extend the agent's reasoning and behaviour.

### Supply-Chain Hardening

Build scripts in `scripts/` enforce pinned dependencies and reproducible builds to reduce supply-chain risk.

---

## Operation Modes (coding-agent)

| Mode        | Description                                           |
|-------------|-------------------------------------------------------|
| Interactive | Full TUI with streaming output and user input         |
| Print       | Non-interactive, output piped to stdout               |
| RPC         | Programmatic control via structured API               |
