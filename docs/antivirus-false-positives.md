# Antivirus False Positives (Windows Defender)

When you run Goose on a managed Windows machine, your endpoint antivirus
(Microsoft Defender, and most EDR tools) may raise alerts about Goose. These are
almost always **false positives** - Goose is doing something completely benign,
but the *shape* of the command looks like malware.

This page explains why it happens, the specific patterns that trigger it, and how
to reduce the noise. Nothing here changes what Goose *does* for you; it changes
*how* it does it so your security tooling stops flagging it.

## Why it happens

Defender's machine-learning heuristics flag the **form** of a command, not its
intent. A command that downloads a file to a temp folder and runs it looks
identical whether it is fetching a documentation file or dropping a credential
stealer. Detections with names ending in `.R!ml` (for example
`Behavior:Win32/...` or a "ClickFix" verdict) are heuristic guesses based on
shape, not signatures of known-bad files.

So the fix is twofold:

1. Stop Goose from **producing** the malware-shaped commands (steer the model).
2. For the parts that are unavoidable (Goose provisioning its own runtime),
   get a **narrowly scoped** antivirus exclusion from whoever administers
   Defender on your machine.

## The patterns that trigger it

Three common triggers, in rough order of how easy they are to fix:

### 1. Chained download-and-run ("ClickFix") - model behavior, fixable

The model decides to fetch something by chaining a shell download into
PowerShell, for example:

```
cmd /C curl -s https://example/thing.md -o %TEMP%\thing.md && powershell -NoProfile -Command ...
```

`cmd -> curl -> powershell` in one line is the "ClickFix" malware signature and
trips a detection almost every time, regardless of what is actually fetched.
**This is driven by the model**, so it is fixable with a hint (see below).

### 2. Runtime auto-provisioning - Goose behavior, usually one-off

Goose can download its own Node.js runtime into `%TEMP%` and unzip it, for
example:

```
Invoke-WebRequest -Uri 'https://nodejs.org/dist/.../node-...-win-x64.zip' -OutFile '%TEMP%\goose-node-...zip'
Expand-Archive -Path '%TEMP%\goose-node-...zip' ...
```

Download-to-temp-then-expand is a classic dropper heuristic. This is **Goose the
binary**, not the model, so a hint will not stop it. It usually happens once
during setup and then stops. Installing a system Node (below) removes the reason
Goose self-provisions.

### 3. Unsigned runtime making web requests - Goose/MCP behavior

An MCP server that runs on an **unsigned `node.exe` from a user-writable path**
(for example `%APPDATA%\fnm\...\node.exe`) and then makes outbound web calls can
trip the "possible theft of passwords / browser information" heuristic. An
unsigned binary in AppData doing network egress looks like an infostealer to
Defender. Running the MCP on a **signed, system-installed Node** avoids this.

## Fix 1: Steer the model with a Goose hint

Add the block below to your **global** Goose hints so it applies to every
session. The global hints file is:

- Generic / CLI: `~/.config/goose/.goosehints`
- Windows Desktop: `%APPDATA%\Block\goose\config\.goosehints`

```markdown
## Windows Defender hygiene - avoid command shapes that look like malware
Defender's ML heuristics flag the *form* of a command, not its intent. Avoid
these shapes even for completely harmless tasks:
- NEVER chain `cmd /C ... && powershell ...`, and never pipe/chain a download
  into a shell (`curl ... && powershell`, `irm ... | iex`, `curl ... | sh`).
  This is the "ClickFix" signature and triggers a detection every single time.
- To read remote content (docs, maps, config), use the built-in fetch/web tools
  or a search extension - do NOT shell out to `curl`/`Invoke-WebRequest`. For
  local files use the Read/developer tools.
- NEVER download a file and then execute or `Expand-Archive` it in the same or a
  following step, and never fetch into `%TEMP%` then run/expand from there.
- If you genuinely must run PowerShell, write the script to a `.ps1` file and run
  that file. Never use a long inline `-Command` or any `-EncodedCommand`/base64.
```

## Fix 2: Run MCP servers on system Node, not an AppData Node

If you configure an MCP server (for example a web-search MCP) that runs on Node,
point it at a **signed, system-installed** Node rather than one under your user
profile:

1. Install Node from the official package (or `winget install OpenJS.NodeJS.LTS`).
2. In Goose's `config.yaml`, set the extension's `cmd` to the Program Files Node,
   for example `C:\Program Files\nodejs\node.exe`, instead of a
   `%APPDATA%\fnm\...\node.exe` path.

A signed binary from `Program Files` is far less likely to trip the infostealer
heuristic than an unsigned one in a user-writable directory. Installing a system
Node also removes the reason Goose auto-downloads its own runtime (trigger 2).

## Fix 3: Ask for a scoped antivirus exclusion

On a managed machine only your Defender/EDR administrator can add exclusions, so
this usually means a support ticket. Ask for a **narrowly scoped** exclusion -
**never** a blanket `%TEMP%` exclusion, which is genuinely dangerous:

- **Process/path exclusions** for Goose's own directories:
  - the Goose install directory (where the Goose binary lives), and
  - `%APPDATA%\Block\goose\`
- The Node runtime path once you move to system Node: `C:\Program Files\nodejs\`
- Ask them to **submit the detections as false positives** to Microsoft
  (Defender portal -> Submissions) so the model stops flagging Goose's signature.

Frame the request plainly: *Goose is an approved local AI-agent developer tool;
these are confirmed false positives on its normal download and runtime behavior.*

## The bottom line

- The alerts are false positives - Goose is not doing anything malicious.
- Fix 1 (the hint) removes the biggest and most repetitive source of noise and
  needs no admin rights.
- Fixes 2 and 3 clean up the runtime-level triggers; Fix 3 needs your Defender
  administrator.
- If an alert does fire, capture the detection name and the exact command from
  the alert - that tells you which of the three patterns it was.
