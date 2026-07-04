# Global Goose Hints (Shell Hygiene)

Goose can read a `.goosehints` file and treat it as standing instructions for
every turn. A **global** hints file lives next to Goose's config and applies to
**all** sessions; a **project** `.goosehints` in a working directory stacks on
top of it.

This page adds a small global hints file whose job is to keep **tool output
small**, so a single command can't balloon your context.

## Why this matters

Goose keeps the whole conversation - including the output of every command it
runs - in the model's context window. One careless command can dump a huge blob
into that window:

- `find / -name SKILL.md` walks the entire filesystem.
- `cat` / `grep` on a large file or directory prints everything.

Two things go wrong when that happens:

1. The session gets slow and expensive, and auto-compaction fires early.
2. On some providers (notably **GitHub Enterprise Copilot**), an oversized,
   tool-heavy turn can come back **empty** - Goose then reports
   *"No message in API response. This may indicate a quota limit or other
   restriction."* even though your quota and model are fine.

A few standing rules prevent the whole class of problem.

## Where the file lives

| OS | Path |
| --- | --- |
| macOS / Linux | `~/.config/goose/.goosehints` |
| Windows | `%APPDATA%\Block\goose\config\.goosehints` |

Goose reads it at **session start**, so start a new chat (or restart Goose)
after creating or editing it.

## The recommended rules

```
# Global Goose hints - apply to every session.

## Shell hygiene - keep tool output small
- Never scan from `/`. Scope searches to specific directories
  (e.g. the project dir, ~/.agents/skills, /mnt/skills).
- Cap long output: pipe through `head`/`tail`, and prefer counts
  (`wc -l`, `grep -c`) over full dumps.
- For file discovery use `rg --files -g PATTERN <dir>` instead of `find /`.
- Redirect large intermediate output to a temp file, then read only what you
  need: `cmd > /tmp/out.txt; wc -l /tmp/out.txt`.
```

## Enforce it at the harness level too

Hints *ask* the model to keep output small; they don't guarantee it. For a hard
backstop, Goose has an environment variable that **caps the size of any single
tool result**:

```
GOOSE_MAX_TOOL_RESPONSE_SIZE   # bytes; a larger tool output is truncated
```

Even if the model runs a `find /` or `cat` on something huge, Goose truncates the
result before it reaches the context - so one command can't flood a turn (a
failure mode that, on GitHub Enterprise Copilot, can make the turn come back
empty). The install scripts set this alongside the context settings with a
conservative default of `50000` bytes. Raise it if you routinely read large
files, or lower it to be stricter:

```bash
./scripts/install.sh --max-tool-response-size 100000
```

```powershell
./scripts/install.ps1 -MaxToolResponseSize 100000
```

The exact behaviour of this variable can change across Goose versions - confirm
against <https://goose-docs.ai/docs/> if truncation looks off.

## How the install scripts set it

Both `scripts/install.sh` and `scripts/install.ps1` write this file for you -
but only if one doesn't already exist, so your own custom hints are never
overwritten.

**macOS / Linux (bash):**

```bash
./scripts/install.sh                 # writes ~/.config/goose/.goosehints if absent
./scripts/install.sh --skip-hints    # leave hints untouched
```

**Windows (PowerShell):**

```powershell
./scripts/install.ps1                 # writes the .goosehints if absent
./scripts/install.ps1 -SkipHints      # leave hints untouched
```

## Setting it by hand

Create the file at the path for your OS (see above) with the recommended rules,
then restart Goose. If a global `.goosehints` already exists, just append the
`## Shell hygiene` block to it.

## Good to know

- **The Developer extension must be enabled** for hints to take effect. It's on
  by default; if hints seem ignored, check it's still enabled in `goose configure`.
- **Project hints stack on top.** A `.goosehints` in a project's working
  directory is applied in addition to the global one, so you can add
  project-specific guidance without repeating the global rules. Goose loads them
  hierarchically from the working directory up to the repo root.
- **Goose also reads `AGENTS.md`** alongside `.goosehints`. To reuse an existing
  rules file such as `CLAUDE.md`, set the `CONTEXT_FILE_NAMES` environment
  variable to include that filename.
- **Keep it short.** Hints are prepended to context every turn; a handful of
  crisp bullet points works better than a long document.
- Read at session start only - restart Goose (or start a new chat) after editing.
