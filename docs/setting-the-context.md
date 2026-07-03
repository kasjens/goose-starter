# Setting the Goose Context (Auto-Compaction)

Goose keeps your whole conversation in the model's **context window**. As a session
grows, that window fills up. Goose watches how full it is and, at a threshold,
runs **auto-compaction** - it summarizes the older parts of the conversation so
the session can keep going.

The catch: on large-window models the default trigger point can be very high
(hundreds of thousands of tokens). Long before that, a session gets slow, more
expensive, and less sharp. It is usually better to compact **earlier** so Goose
stays fast and focused.

This page shows the two settings that control that, and the sensible defaults the
install scripts apply for you.

## The two settings

| Setting | What it does | Values | Default |
| --- | --- | --- | --- |
| `GOOSE_AUTO_COMPACT_THRESHOLD` | The percentage of the tracked context limit at which Goose auto-summarizes the session. | Float between 0.0 and 1.0 (0.0 disables) | 0.8 |
| `GOOSE_CONTEXT_LIMIT` | Overrides the context limit (in tokens) Goose tracks for the main model. | Integer number of tokens | Model-specific default, or 128,000 |

Auto-compaction fires at roughly:

```
trigger tokens  =  GOOSE_CONTEXT_LIMIT  x  GOOSE_AUTO_COMPACT_THRESHOLD
```

So there are two ways to compact sooner: lower the **threshold**, and/or lower the
**tracked limit**. Setting both gives you a predictable trigger that does not
change from model to model.

## Recommended values

For a predictable trigger around ~140k tokens regardless of which model you are on:

```
GOOSE_CONTEXT_LIMIT=200000
GOOSE_AUTO_COMPACT_THRESHOLD=0.7
```

`200000 x 0.7 = 140000` tokens.

These are the defaults the [install scripts](../scripts) apply. If you would
rather leave the tracked limit alone and only change when compaction fires,
adjust the threshold on its own:

| Model context window | Threshold for a ~140k trigger |
| --- | --- |
| 1,000,000 | 0.15 |
| 500,000 | 0.28 |
| 256,000 | 0.55 |
| 200,000 | 0.70 |

## How the install scripts set it

Both `scripts/install.ps1` and `scripts/install.sh` set these two variables for
you (persisted, so new terminals and Goose sessions pick them up).

**Windows (PowerShell):**

```powershell
# Uses the recommended defaults (200000 / 0.7):
./scripts/install.ps1

# Or choose your own:
./scripts/install.ps1 -ContextLimit 150000 -AutoCompactThreshold 0.8

# Or leave the context settings untouched:
./scripts/install.ps1 -SkipContext
```

**macOS / Linux (bash):**

```bash
# Uses the recommended defaults (200000 / 0.7):
./scripts/install.sh

# Or choose your own:
./scripts/install.sh --context-limit 150000 --auto-compact-threshold 0.8

# Or leave the context settings untouched:
./scripts/install.sh --skip-context
```

## Setting it by hand

If you prefer not to use the scripts, set the variables yourself.

**Windows (PowerShell), persisted for your user:**

```powershell
[Environment]::SetEnvironmentVariable('GOOSE_CONTEXT_LIMIT', '200000', 'User')
[Environment]::SetEnvironmentVariable('GOOSE_AUTO_COMPACT_THRESHOLD', '0.7', 'User')
```

**macOS / Linux (bash/zsh),** add to your shell profile (`~/.zshrc`, `~/.bashrc`):

```bash
export GOOSE_CONTEXT_LIMIT=200000
export GOOSE_AUTO_COMPACT_THRESHOLD=0.7
```

Open a new terminal (or `source` your profile) and restart Goose so it reads the
new values.

## Changing or disabling later

- **Compact sooner / later:** lower or raise `GOOSE_AUTO_COMPACT_THRESHOLD`
  (e.g. `0.6` compacts sooner, `0.85` later).
- **Disable auto-compaction:** set `GOOSE_AUTO_COMPACT_THRESHOLD=0.0`.
- **Trigger compaction manually at any time:** use the `/summarize` command in the
  Goose CLI, or `Compact now` from the token indicator in Goose Desktop.

## Good to know

- These are **environment variables**. `GOOSE_CONTEXT_LIMIT` only works as an
  environment variable, not from the `config.yaml` file. Environment variables
  also take precedence over config-file settings.
- `GOOSE_CONTEXT_LIMIT` only affects the **token usage that Goose displays and the
  point at which it compacts**. The real context handling is done by the model, so
  actual usage may differ from the number you set - which is fine here, because the
  goal is simply to compact earlier than the model's true maximum.
- Restart Goose (and open a new terminal for the CLI) after changing these so the
  new values are picked up.

## More detail

See the official Goose documentation:

- Smart Context Management: <https://goose-docs.ai/docs/guides/sessions/smart-context-management>
- Environment Variables: <https://goose-docs.ai/docs/guides/environment-variables>
