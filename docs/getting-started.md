# Getting Started with Goose

This guide walks you through installing Goose so you can start building with AI.

## 1. Download and install Goose

Go to the official Goose docs and follow the download/install instructions:

- **Goose website:** https://goose-docs.ai/
- **Source & releases:** https://github.com/aaif-goose/goose

Download the version for your operating system and install it from there. The
CLI installer, and the desktop `.deb` / `.rpm` / Flatpak assets, live on the
[releases page](https://github.com/aaif-goose/goose/releases).

> **Note:** Goose moved from `block/goose` to `aaif-goose/goose` under the Linux
> Foundation's Agentic AI Foundation. Use the `aaif-goose` repo and
> `goose-docs.ai` - old `block.github.io/goose` links still resolve but are being
> retired.

## 2. Install a package manager (recommended)

A package manager makes installing and updating tools much easier.

### Windows

Install **Scoop** to enable package management:

- **Scoop:** https://scoop.sh/

Open PowerShell and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

### macOS

Install **Homebrew**, the macOS equivalent of Scoop:

- **Homebrew:** https://brew.sh/

Open Terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Linux

Most Linux distributions ship with a package manager already (e.g. `apt`, `dnf`, `pacman`). You can also use **Homebrew on Linux** if you prefer:

- **Homebrew:** https://brew.sh/

## 3. Next steps

Once Goose is installed, verify it works and continue with the setup steps on the [Goose website](https://goose-docs.ai/).
