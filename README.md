# goose-starter

A beginner-friendly starter repo for getting up and running with AI using
[Goose](https://goose-docs.ai/) — an open-source AI agent you run on your own
machine. It can use tools, run commands, and extend itself with **skills**.

This repo gives you scripts and step-by-step docs so you can go from nothing to a
working Goose setup, even if it's your first time.

## Contents

- [What you'll set up](#what-youll-set-up)
- [Prerequisites](#prerequisites)
- [Quick install](#quick-install)
- [Getting started (manual)](#getting-started-manual)
- [Adding skills](#adding-skills)
- [GitHub Enterprise Copilot (optional)](#github-enterprise-copilot-optional)
- [Repo layout](#repo-layout)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [About Goose](#about-goose)

## What you'll set up

1. A **package manager** so tools and dependencies install cleanly
   (Scoop on Windows, Homebrew on macOS/Linux).
2. **Goose** itself.
3. *(Optional)* **Skills** that extend what Goose can do.
4. *(Optional)* A **company GitHub Enterprise Copilot** seat as Goose's model
   provider.

## Prerequisites

- Windows, macOS, or Linux.
- Permission to install software on your machine (installing a package manager
  may prompt for your password / admin rights).
- An internet connection.
- A terminal: **PowerShell** on Windows, **Terminal** on macOS/Linux.

## Quick install

The [`scripts/`](scripts/) folder has re-runnable install/update scripts. They
install (or update) your package manager, open the Goose download page, and can
optionally configure a GitHub Enterprise Copilot seat.

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

The scripts are **idempotent** — safe to re-run any time to update. They back up
every file they edit to `<file>.bak`, and print the manual sign-in steps that
can't be automated.

> **Note:** The scripts open the official Goose download page rather than
> installing the Goose binary silently, so you install/update it the supported
> way for your OS. Everything else is automated.

Prefer to do it entirely by hand? Follow the manual guide below.

## Getting started (manual)

Work through these in order:

1. **[Install Goose](docs/getting-started.md)** — install a package manager
   (Scoop / Homebrew), then download and install Goose.
2. **[Import skills](docs/importing-skills.md)** — add ready-made skills and let
   Goose install their dependencies.
3. **[Use a GitHub Enterprise Copilot seat](docs/goose-github-enterprise-copilot.md)**
   *(optional)* — point Goose at your company's enterprise Copilot.

## Adding skills

Skills are reusable capabilities you can drop into Goose. You don't install them
by hand — just ask Goose to import them from a repository, for example:

> Import the skills from https://github.com/anthropics/skills and install any
> dependencies they need.

Sources covered in the docs:

- [anthropics/skills](https://github.com/anthropics/skills)
- [MiniMax-AI/skills](https://github.com/MiniMax-AI/skills)

Goose fetches the skills, works out what they need, and installs dependencies
using the package manager on your system. See
[Importing Skills](docs/importing-skills.md) for details.

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
├── README.md                              # you are here
├── docs/
│   ├── getting-started.md                 # install Goose + a package manager
│   ├── importing-skills.md                # add skills and their dependencies
│   └── goose-github-enterprise-copilot.md # optional enterprise Copilot setup
└── scripts/
    ├── install.sh                         # macOS / Linux install + update
    └── install.ps1                        # Windows install + update
```

## Documentation

| Guide | What it covers |
| --- | --- |
| [Getting Started](docs/getting-started.md) | Installing Goose and a package manager |
| [Importing Skills](docs/importing-skills.md) | Adding skills from GitHub and installing dependencies |
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
  (not **Auto**) — Goose saves the last-used model as the default on exit.

## About Goose

Goose is an AI agent that runs locally and can use tools, run commands, and
extend itself with skills. Learn more at the official docs:
<https://goose-docs.ai/>.
