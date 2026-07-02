# Importing Skills into Goose

Skills extend what Goose can do. You can import ready-made skills from public repositories and let Goose install anything they need.

## Where to get skills

- **Anthropic skills:** https://github.com/anthropics/skills
- **MiniMax skills:** https://github.com/MiniMax-AI/skills

## How to import them

You don't need to install skills by hand. Inside Goose, just ask it to do it for you. For example:

> Import the skills from https://github.com/anthropics/skills and install any dependencies they need.

or

> Add the skills from https://github.com/MiniMax-AI/skills and set up whatever they require.

Goose will:

1. Fetch the skills from the repository you point it at.
2. Read what each skill needs to run.
3. Install any missing dependencies using the package manager on your system (e.g. **Scoop** on Windows, **Homebrew** on macOS, or your Linux distro's package manager).

## Before you start

Make sure you have a package manager installed so Goose can pull in dependencies automatically. See [Getting Started](getting-started.md) for how to install Scoop (Windows) or Homebrew (macOS).
