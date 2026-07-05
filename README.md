# goose-starter

A beginner-friendly starter repo for getting up and running with AI using
[Goose](https://goose-docs.ai/) - an open-source AI agent you run on your own
machine. It can use tools, run commands, and extend itself with **skills**.

This repo gives you scripts and step-by-step docs so you can go from nothing to a
working Goose setup, even if it's your first time.

## Contents

- [Start here](#start-here)
- [What you'll set up](#what-youll-set-up)
- [Prerequisites](#prerequisites)
- [Quick install](#quick-install)
- [Getting started (manual)](#getting-started-manual)
- [Adding skills](#adding-skills)
- [Best practices](#best-practices)
  - [Setting the context](#setting-the-context)
  - [Global hints (shell hygiene)](#global-hints-shell-hygiene)
  - [Securing extension secrets](#securing-extension-secrets)
- [GitHub Enterprise Copilot (optional)](#github-enterprise-copilot-optional)
- [Repo layout](#repo-layout)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [About Goose](#about-goose)

## Start here

New to Goose? Follow this path top to bottom - each step links to its section:

1. Check the [Prerequisites](#prerequisites).
2. Run the [Quick install](#quick-install) script for your OS (or do it by hand
   with the [manual guide](#getting-started-manual)).
3. Finish in Goose: install the app, connect a model provider, and start your
   first session - the [After the script runs](#after-the-script-runs) steps
   walk you through it.
4. Skim [Best practices](#best-practices). The install scripts already apply
   these for you; it's worth knowing what they do and how to tune them.

Everything here is safe to re-run, so you can't get into a broken state by
experimenting.

## What you'll set up

1. A **package manager** so tools and dependencies install cleanly
   (Scoop on Windows, Homebrew on macOS/Linux).
2. **Goose** itself.
3. Sensible **context settings** so long sessions stay fast and focused
   (auto-compaction fires earlier, and a single tool call can't flood the context).
4. Global **shell-hygiene hints** so Goose keeps command output small and
   doesn't balloon your context.
5. *(Optional)* **Skills** that extend what Goose can do.
6. *(Optional)* A **company GitHub Enterprise Copilot** seat as Goose's model
   provider.

## Prerequisites

- Windows, macOS, or Linux.
- Permission to install software on your machine (installing a package manager
  may prompt for your password / admin rights).
- An internet connection.
- A terminal: **PowerShell** on Windows, **Terminal** on macOS/Linux.

## Quick install

The [`scripts/`](scripts/) folder has re-runnable install/update scripts. They
install (or update) your package manager, open the Goose download page, apply
sensible context settings, write global shell-hygiene hints, and can optionally
configure a GitHub Enterprise Copilot seat.

**Windows (PowerShell):**

```powershell
./scripts/install.ps1
# with enterprise Copilot:
./scripts/install.ps1 -EnterpriseHost your-company.ghe.com -DefaultModel claude-opus-4.8
```

**macOS / Linux (bash):**

```bash
./scripts/install.sh
# with enterprise Copilot:
./scripts/install.sh --enterprise-host your-company.ghe.com --model claude-opus-4.8
```

The scripts are **idempotent** - safe to re-run any time to update. They back up
every file they edit to `<file>.bak`, and print the manual sign-in steps that
can't be automated.

> **Note:** The scripts open the official Goose download page rather than
> installing the Goose binary silently, so you install/update it the supported
> way for your OS. Everything else is automated.

### After the script runs

The script sets up your machine; a few steps happen inside Goose itself:

1. **Install/update Goose** from the download page the script opened.
2. **Launch Goose** - the desktop app, or `goose configure` in a terminal.
3. **Connect a model provider** - an Anthropic API key, or a GitHub Copilot
   seat. Follow the provider setup on the [Goose docs](https://goose-docs.ai/).
   Company Copilot users: see
   [GitHub Enterprise Copilot](#github-enterprise-copilot-optional).
4. **Pick a model, then start a session** and ask it something (e.g. "list your
   available tools") to confirm the provider works.

Prefer to do it entirely by hand? Follow the manual guide below.

## Getting started (manual)

Work through these in order:

1. **[Install Goose](docs/getting-started.md)** - install a package manager
   (Scoop / Homebrew), then download and install Goose.
2. **Connect a provider & start a session** - add an Anthropic API key or a
   GitHub Copilot seat via the [Goose docs](https://goose-docs.ai/), then run a
   session to confirm it works.
3. **[Apply the best practices](#best-practices)** - set the context limits and
   global hints by hand (the quick-install scripts do this for you).
4. **[Import skills](docs/importing-skills.md)** *(optional)* - add ready-made
   skills and let Goose install their dependencies.
5. **[Use a GitHub Enterprise Copilot seat](docs/goose-github-enterprise-copilot.md)**
   *(optional)* - point Goose at your company's enterprise Copilot.

## Adding skills

Skills are reusable capabilities you can drop into Goose. You don't install them
by hand - just ask Goose to import them from a repository, for example:

> Import the skills from https://github.com/anthropics/skills and install any
> dependencies they need.

Sources covered in the docs:

- [anthropics/skills](https://github.com/anthropics/skills)
- [MiniMax-AI/skills](https://github.com/MiniMax-AI/skills)

Goose fetches the skills, works out what they need, and installs dependencies
using the package manager on your system. See
[Importing Skills](docs/importing-skills.md) for details.

## Best practices

These are the settings that keep long sessions fast, cheap, and reliable. The
**quick-install scripts apply the first two for you** (context and hints) - this
section explains what they do so you can tune or set them by hand. Securing
extension secrets is a manual practice the scripts deliberately don't automate.
Each is safe to change or skip.

### Setting the context

Goose keeps your whole conversation in the model's context window and
auto-compacts (summarizes) it when it gets full. On large-window models the
default trigger point can be very high, so a session gets slow and expensive long
before it kicks in. It's usually better to compact **earlier**.

The install scripts set three environment variables for you so this happens
automatically:

- `GOOSE_CONTEXT_LIMIT` - the tracked context window (default `200000`).
- `GOOSE_AUTO_COMPACT_THRESHOLD` - the fraction of that limit at which Goose
  compacts (default `0.7`, i.e. around 140,000 tokens).
- `GOOSE_MAX_TOOL_RESPONSE_SIZE` - caps a single tool result so one command can't
  flood the context in a turn (default `50000` bytes).

Override them if you like:

```powershell
# Windows
./scripts/install.ps1 -ContextLimit 150000 -AutoCompactThreshold 0.8 -MaxToolResponseSize 100000
./scripts/install.ps1 -SkipContext          # leave them untouched
```

```bash
# macOS / Linux
./scripts/install.sh --context-limit 150000 --auto-compact-threshold 0.8 --max-tool-response-size 100000
./scripts/install.sh --skip-context         # leave them untouched
```

Full explanation, per-model guidance, and how to set it by hand:
[Setting the Context](docs/setting-the-context.md).

### Global hints (shell hygiene)

Goose reads a global `.goosehints` file into **every** session. The scripts drop
in a small set of rules covering two things: **shell hygiene** that keeps tool
output small - no whole-filesystem `find /` scans, cap long output, prefer counts
- and **secret safety** so Goose won't `cat` a `config.yaml`/`secrets.yaml`/`.env`
into the conversation or write a key into a commit. The shell-hygiene half stops a
single command from ballooning your context (which, on GitHub Enterprise Copilot,
can even make a turn come back empty with *"No message in API response"*).

Hints only *ask* the model to behave; the `GOOSE_MAX_TOOL_RESPONSE_SIZE` env var
above is the hard backstop that *truncates* an oversized tool result regardless.
The two work together.

The file is written only if one doesn't already exist, so your own custom hints
are never overwritten:

```powershell
# Windows
./scripts/install.ps1 -SkipHints      # don't write the global .goosehints
```

```bash
# macOS / Linux
./scripts/install.sh --skip-hints     # don't write the global .goosehints
```

Where it lives, the exact rules, and how to set it by hand:
[Global Goose Hints](docs/goose-hints.md).

### Securing extension secrets

Some extensions need an API key or token - for example the Brave Search
extension needs a `BRAVE_API_KEY`. If you paste the key straight into the
extension, it can end up stored in **plaintext** inside Goose's `config.yaml`.

Store it in your system **keyring** instead. The short version:

- Declare the variable **name** in the extension's `env_keys` (not its value in
  `envs`).
- Enter the actual key through `goose configure`, which saves it to the keyring
  and reuses it on later runs.
- If a key was ever stored in plaintext, **rotate it** - it may also be sitting
  in `config.yaml.bak*` backups and your shell history.

The install scripts don't touch extension secrets (they can't script the
interactive keyring prompt), so this is a manual best practice. Full walkthrough,
including how to spot an exposed key and clean up backups:
[Securing Extension Secrets](docs/securing-extension-secrets.md).

> **Heads-up:** this repo's `.gitignore` already excludes `config.yaml`,
> `secrets.yaml`, and `*.bak` files so you can't accidentally commit a key from a
> local Goose setup. Keep it that way.

## GitHub Enterprise Copilot (optional)

If your organization provides a **company-backed GitHub Enterprise Copilot**
seat, you can use it as Goose's model provider so authentication and traffic stay
inside your enterprise tenant. This involves:

- setting `GITHUB_COPILOT_HOST` to your enterprise host,
- a one-time device-flow sign-in against your tenant,
- optionally pinning a default model in Goose's `config.yaml`.

The install scripts automate the parts that can be scripted; the sign-in is
manual. Full walkthrough:
[GitHub Enterprise Copilot](docs/goose-github-enterprise-copilot.md).

## Repo layout

```
goose-starter/
|-- README.md                              # you are here
|-- .gitignore                             # keeps secrets/backups (config.yaml, *.bak) out of git
|-- docs/
|   |-- getting-started.md                 # install Goose + a package manager
|   |-- importing-skills.md                # add skills and their dependencies
|   |-- setting-the-context.md             # tune auto-compaction / context limit
|   |-- goose-hints.md                     # global .goosehints shell-hygiene rules
|   |-- securing-extension-secrets.md      # move API keys out of config.yaml into the keyring
|   `-- goose-github-enterprise-copilot.md # optional enterprise Copilot setup
`-- scripts/
    |-- install.sh                         # macOS / Linux install + update
    `-- install.ps1                        # Windows install + update
```

## Documentation

| Guide | What it covers |
| --- | --- |
| [Getting Started](docs/getting-started.md) | Installing Goose and a package manager |
| [Importing Skills](docs/importing-skills.md) | Adding skills from GitHub and installing dependencies |
| [Setting the Context](docs/setting-the-context.md) | Tuning auto-compaction so long sessions stay fast |
| [Global Goose Hints](docs/goose-hints.md) | Shell-hygiene rules that keep tool output small |
| [Securing Extension Secrets](docs/securing-extension-secrets.md) | Moving API keys out of `config.yaml` into the system keyring |
| [GitHub Enterprise Copilot](docs/goose-github-enterprise-copilot.md) | Configuring Goose against an enterprise Copilot seat |

## Troubleshooting

- **`install.sh` won't run (permission denied):** make it executable with
  `chmod +x scripts/install.sh`, then run `./scripts/install.sh`.
- **PowerShell blocks the script:** run
  `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` once,
  then re-run `./scripts/install.ps1`.
- **`brew` / `scoop` not found after install:** open a **new** terminal so your
  updated `PATH` is picked up, then re-run the script.
- **Enterprise sign-in goes to public github.com:** make sure
  `GITHUB_COPILOT_HOST` is set and that you fully quit and relaunched Goose
  afterwards. The env var must be set *before* signing in.
- **Pinned model keeps resetting:** in Goose's model picker choose your model
  (not **Auto**) - Goose saves the last-used model as the default on exit.

## About Goose

Goose is an AI agent that runs locally and can use tools, run commands, and
extend itself with skills. It's an open-source project under the Linux
Foundation's Agentic AI Foundation (it moved from `block/goose` to
`aaif-goose/goose`). Learn more:

- **Docs:** <https://goose-docs.ai/>
- **Source & releases:** <https://github.com/aaif-goose/goose>
