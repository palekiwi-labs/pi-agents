# Customizing Pi Tools: Factories and Hooks

Pi is designed to be highly extensible. While you can add entirely new tools, you can also wrap, modify, or replace the built-in "standard library" of tools (bash, read, write, etc.) using factory functions and lifecycle hooks.

---

## Tool Factory Functions

Standard tools are created via factory functions exported from `@earendil-works/pi-coding-agent`. These factories take a `cwd` (Current Working Directory) and an optional `options` object for customization.

### Available Factories

| Factory | Tool Name | Purpose |
| :--- | :--- | :--- |
| `createBashTool` | `bash` | Execute shell commands. |
| `createReadTool` | `read` | Read file contents (supports images). |
| `createWriteTool` | `write` | Write/Overwrite files. |
| `createEditTool` | `edit` | Perform exact string replacements in files. |
| `createLsTool` | `ls` | List directory contents. |
| `createFindTool` | `find` | Find files using glob patterns. |
| `createGrepTool` | `grep` | Search file contents using regex. |

---

## The `spawnHook` (Bash Only)

The `bash` tool provides a specialized `spawnHook` which allows you to intercept and mutate a command just before it is executed in the shell.

### Use Cases:
- **Environment Injection**: Add secrets or configuration to `env`.
- **Shell Customization**: Prefix commands with `source ~/.profile` or `conda activate`.
- **Safety/Validation**: Inspect the `command` string and throw an error if it contains dangerous patterns (e.g., `rm -rf /`).

### Example:
```typescript
const bashTool = createBashTool(cwd, {
  spawnHook: ({ command, cwd, env }) => ({
    command: `echo "Starting execution..." && ${command}`,
    cwd,
    env: { ...env, DEBUG: "true" }
  })
});
```

---

## The `operations` Hook (Universal)

Most tool factories accept an `operations` object. This allows you to replace the low-level "engine" that interacts with the system. This is the primary way to implement virtual filesystems or remote execution.

### Logic Flow:
1. **LLM** calls tool (e.g., `read`).
2. **Tool Logic** validates parameters and handles agent-specific logic (e.g., image resizing).
3. **Operations** performs the actual system call (e.g., `fs.readFile`).

### Example: Custom Read Operations
```typescript
const readTool = createReadTool(cwd, {
  operations: {
    readFile: async (path) => {
      if (path.includes("secret")) throw new Error("Access Denied");
      return await fs.promises.readFile(path, "utf-8");
    }
  }
});
```

---

## Global Event Hooks

If you want to observe or react to tools without replacing them, you can use the `ExtensionAPI` event system.

| Event | Description |
| :--- | :--- |
| `tool_call` | Emitted when the agent decides to call a tool. |
| `tool_output` | Emitted when a tool finishes execution. |

### Example: Logging Tool Usage
```typescript
export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    ctx.ui.notify(`Agent is using ${event.toolName}`, "info");
  });
}
```

---

## Registration and Overriding

Tools are registered via `pi.registerTool(tool)`. 

- **Custom Names**: If you give your tool a unique name, it is added to the agent's toolbox.
- **Overriding**: If you register a tool with the same name as a built-in tool (e.g., "bash"), your version **replaces** the default one for that session.

---

## Summary of Extension Types

1. **Simple Tool**: New capability using `defineTool`.
2. **Customized Built-in**: Existing capability modified via factory (e.g., `createBashTool`) + `spawnHook` or `operations`.
3. **Passive Observer**: Uses `pi.on("tool_call", ...)` to watch behavior without interfering.
