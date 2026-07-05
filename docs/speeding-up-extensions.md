# Speeding Up Slow Extensions (`npx`/`uvx` launch cost)

Some Goose extensions load **slowly every time a session starts** - a few
seconds of delay before the extension is ready, on each launch. If an extension
is configured to run through `npx -y ...` (Node) or `uvx ...` (Python), that
delay is usually the launcher **re-resolving the package from the registry on
every start**, not the extension itself.

This guide shows how to confirm that's the cause and make the extension start in
about a second instead.

## Why it happens

Many MCP-server extensions are configured like this (the Brave Search extension
is a typical example):

```yaml
  bravesearch:
    type: stdio
    cmd: npx
    args:
    - -y
    - '@brave/brave-search-mcp-server'
    - --transport
    - stdio
    env_keys:
    - BRAVE_API_KEY
```

`npx -y <package>` is convenient - it fetches the package if it's missing and
always runs it - but the `-y` means npx **re-checks the package against the npm
registry every single launch**, even when it's already cached. That network
round-trip is the delay you feel each time a session starts. The Python
equivalent, `uvx <package>`, behaves the same way.

The trade-off: `npx -y` / `uvx` always pull the latest version automatically. The
fix below pins the version you have and makes updates a manual step (see
[Keeping it updated](#keeping-it-updated)).

## Step 1 - Confirm the launcher is the bottleneck

Time the exact command from your `config.yaml`. If launching it by hand is slow
too, the delay is the launcher, not Goose.

**macOS / Linux:**

```bash
time npx -y @brave/brave-search-mcp-server --transport stdio </dev/null
```

**Windows (PowerShell):**

```powershell
Measure-Command { npx -y '@brave/brave-search-mcp-server' --transport stdio } # Ctrl+C once it's up
```

A few seconds every run (rather than sub-second) points at the re-resolve step.

## Step 2 - Install the package once, globally

Install it so it lives on disk and doesn't need re-fetching:

**Node (npx-based extensions):**

```bash
npm install -g @brave/brave-search-mcp-server
```

**Python (uvx-based extensions):**

```bash
uv tool install <package>        # installs a persistent tool instead of uvx's throwaway run
```

## Step 3 - Point the extension straight at it

Edit the extension block in your `config.yaml` so `cmd` runs the installed
program directly, skipping the resolve step. There are two ways - pick one.

> **Find your config.yaml:** `~/.config/goose/config.yaml` on macOS/Linux, or
> `%APPDATA%\Block\goose\config\config.yaml` on Windows. Back it up first
> (`cp config.yaml config.yaml.bak`) - Goose also does this for you if you use
> the install scripts.

### Option A - call the installed launcher (simplest)

`npm install -g` drops a launcher on your `PATH`. Point `cmd` at it and drop the
`-y` / package-name args:

```yaml
  bravesearch:
    type: stdio
    cmd: brave-search-mcp-server        # the globally-installed launcher
    args:
    - --transport
    - stdio
    env_keys:
    - BRAVE_API_KEY
```

Confirm the launcher's name/location first:

```bash
# macOS / Linux
which brave-search-mcp-server
```

```powershell
# Windows - lists the .cmd / .ps1 shims npm created
Get-Command brave-search-mcp-server
```

### Option B - call the runtime + entry script directly (fastest)

Skip the shell shim entirely and run the interpreter against the package's entry
file. This shaved the most time off in testing.

Find the two paths:

```bash
# Node: the runtime, and the package's entry script
which node
echo "$(npm root -g)/@brave/brave-search-mcp-server/dist/index.js"
```

```powershell
# Windows equivalents
(Get-Command node).Source
Join-Path (npm root -g) '@brave\brave-search-mcp-server\dist\index.js'
```

Then set them literally in `config.yaml` (use **your** paths):

```yaml
  bravesearch:
    type: stdio
    cmd: /full/path/to/node                 # e.g. Windows: C:\...\nodejs\current\node.exe
    args:
    - /full/path/to/@brave/brave-search-mcp-server/dist/index.js
    - --transport
    - stdio
    env_keys:
    - BRAVE_API_KEY
```

> **Leave `env_keys` / `envs` alone.** You're only changing *how* the program is
> launched, not its secrets - the key still comes from your keyring. See
> [Securing Extension Secrets](securing-extension-secrets.md).

## Step 4 - Restart Goose and verify

Fully quit and relaunch Goose (or start a new CLI session) so it re-reads the
config. Then confirm the extension starts cleanly:

```bash
goose doctor       # should list the extension with no "Failed to start" warning
```

Expect roughly a **4x faster** start - in testing, an extension that took ~4s to
launch via `npx -y` came up in ~0.7-1s pointed directly at node.

> **First launch after installing may still be slow.** The very first start after
> a global install can take several seconds while the OS (and, on Windows,
> antivirus) warms its file cache for the newly-written files. Every launch after
> that is the fast path.

## Keeping it updated

`npx -y` / `uvx` auto-updated the package for you; pinning it means updates are
now manual. Refresh it occasionally:

```bash
npm update -g @brave/brave-search-mcp-server     # Node
uv tool upgrade <package>                         # Python
```

If Option B ever stops working after an update (the entry path changed), re-run
the `npm root -g` command from Step 3 to get the new path, or switch to Option A,
which is more stable across updates.

## Good to know

- **This applies to any `npx -y` / `uvx` extension**, not just Brave Search - the
  same slow-resolve-on-every-launch pattern and fix apply across the board.
- **Bundled extensions aren't affected** - only ones that shell out to a package
  runner have this cost.
- **The `GOOSE_MAX_TOOL_RESPONSE_SIZE` cap and startup speed are unrelated** - this
  guide is purely about launch latency, not context size.
