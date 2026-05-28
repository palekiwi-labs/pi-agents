# Jiti and Extension Autoloading in Pi

## Overview

Pi uses **jiti**, a runtime module loader, to enable dynamic, zero-config loading of TypeScript extensions. This allows developers to extend Pi's functionality by simply placing `.ts` files in specific directories without a manual compilation or build step.

---

## What is jiti?

**jiti** (developed by UnJS) is a high-performance runtime that compiles TypeScript and modern ESM (ECMAScript Modules) on the fly for execution in environments like Node.js or Bun. It intercepts the module loading process, handles the transformation from TS to JS in memory, and manages dependency resolution.

---

## Extension Discovery (Autoloading)

Pi automatically scans the following locations for extension files at startup:

1.  **User-Global**: `~/.pi/agent/extensions/*.ts` (available across all projects).
2.  **Project-Local**: `./.pi/extensions/*.ts` (specific to the current workspace).
3.  **Manual**: Extensions provided via the `--extension <path>` CLI flag.

The loading logic is managed in:
`/home/pl/code/earendil-works/pi/packages/coding-agent/src/core/extensions/loader.ts`

---

## Implementation Details

### The Loader Configuration

Pi initializes `jiti` with specific options to support its architectural requirements:

```typescript
// packages/coding-agent/src/core/extensions/loader.ts

import { createJiti } from "jiti/static";

async function loadExtensionModule(extensionPath: string) {
    const jiti = createJiti(import.meta.url, {
        moduleCache: false,    // Disables caching to allow hot-reloading
        alias: getAliases(),   // Maps internal package names to the core logic
        // ... binary-specific settings for Bun
    });

    const module = await jiti.import(extensionPath, { default: true });
    // ... validation and registration logic
}
```

### Key Mechanisms

- **Package Aliasing**: Pi uses `jiti`'s alias feature to map imports like `@earendil-works/pi-coding-agent` back to its own internal modules. This allows extensions to import the `ExtensionAPI` and types without needing a local `node_modules`.
- **Cache Management**: By setting `moduleCache: false`, Pi ensures that if an extension is modified, it can be reloaded without being stuck with a stale version cached by the runtime's native module system.
- **Binary Compatibility**: When Pi is run as a compiled Bun binary, `jiti` is configured with `virtualModules` to resolve core dependencies that are bundled inside the binary rather than existing on the filesystem.

---

## Benefits for Extension Development

1.  **Native TypeScript**: Write extensions in `.ts` with full IDE support (types, autocompletion) and execute them directly.
2.  **Fast Iteration**: No `tsc` or `esbuild` step required. Changes are picked up as soon as the agent reloads.
3.  **Simplified Distribution**: Extensions are often single files that are easy to share and install (just move the file into the `extensions/` directory).
4.  **Environment Agnostic**: The loader provides consistent behavior whether running in a development environment or via a production binary.
