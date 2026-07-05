#!/usr/bin/env bash
#
# install.sh - set up (or update) your machine for Goose on macOS / Linux.
#
# What it automates:
#   1. Installs Homebrew (macOS) if missing, or updates it if present.
#   2. Opens the official Goose download page so you can install/update Goose.
#   3. Sets Goose context / output env vars in your shell profile so long sessions
#      compact earlier and no single tool call floods the context
#      (GOOSE_CONTEXT_LIMIT + GOOSE_AUTO_COMPACT_THRESHOLD + GOOSE_MAX_TOOL_RESPONSE_SIZE).
#   4. Writes a global ~/.config/goose/.goosehints with shell-hygiene rules so Goose
#      keeps tool output small (no whole-filesystem scans, cap output, etc).
#   5. (Optional) Configures Goose for a company GitHub Enterprise Copilot seat:
#        - sets GITHUB_COPILOT_HOST in your shell profile
#        - pins a default Copilot model in Goose's config.yaml
#
# What it CANNOT do (interactive, must be done by hand):
#   - The Goose Copilot device-flow sign-in. Manual steps are printed at the end.
#
# Re-runnable and idempotent. Every file it edits is backed up to "<file>.bak".
#
# Usage:
#   ./install.sh                                  # package manager + Goose + context
#   ./install.sh --enterprise-host your-co.ghe.com --model claude-opus-4.8
#   ./install.sh --context-limit 150000 --auto-compact-threshold 0.8
#   ./install.sh --max-tool-response-size 50000   # cap a single tool output (bytes)
#   ./install.sh --skip-context                   # leave context/output env vars untouched
#   ./install.sh --skip-hints                     # don't write the global .goosehints
#   ./install.sh --skip-goose                     # only configure, don't open download page
#
set -euo pipefail

# ---- defaults --------------------------------------------------------------
ENTERPRISE_HOST=""
DEFAULT_MODEL="claude-opus-4.8"
CONTEXT_LIMIT="200000"
AUTO_COMPACT_THRESHOLD="0.7"
MAX_TOOL_RESPONSE_SIZE="50000"
SKIP_CONTEXT=false
SKIP_HINTS=false
SKIP_PKG_MANAGER=false
SKIP_GOOSE=false
GOOSE_DOCS_URL="https://goose-docs.ai/"

# ---- pretty output ---------------------------------------------------------
step() { printf '\n==> %s\n' "$1"; }
ok()   { printf '    [OK] %s\n' "$1"; }
note() { printf '    [--] %s\n' "$1"; }
warn() { printf '    [!]  %s\n' "$1" >&2; }

# ---- args ------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --enterprise-host) ENTERPRISE_HOST="${2:-}"; shift 2 ;;
        --model)           DEFAULT_MODEL="${2:-}";  shift 2 ;;
        --context-limit)   CONTEXT_LIMIT="${2:-}";  shift 2 ;;
        --auto-compact-threshold) AUTO_COMPACT_THRESHOLD="${2:-}"; shift 2 ;;
        --max-tool-response-size) MAX_TOOL_RESPONSE_SIZE="${2:-}"; shift 2 ;;
        --skip-context)    SKIP_CONTEXT=true; shift ;;
        --skip-hints)      SKIP_HINTS=true; shift ;;
        --skip-package-manager) SKIP_PKG_MANAGER=true; shift ;;
        --skip-goose)      SKIP_GOOSE=true; shift ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) warn "Unknown option: $1"; exit 1 ;;
    esac
done

# Normalise host: strip scheme + trailing slash
ENTERPRISE_HOST="$(printf '%s' "$ENTERPRISE_HOST" | sed -E 's#^https?://##; s#/+$##')"

OS="$(uname -s)"
step "Goose setup ($OS)"
note "Enterprise host: ${ENTERPRISE_HOST:-'(none - public github.com)'}"
note "Default model  : ${DEFAULT_MODEL:-'(skip)'}"
if [ "$SKIP_CONTEXT" = true ]; then
    note "Context        : (skip)"
else
    note "Context        : limit $CONTEXT_LIMIT, threshold $AUTO_COMPACT_THRESHOLD"
    note "Max tool output: $MAX_TOOL_RESPONSE_SIZE bytes"
fi

# Pick the shell profile to persist env vars into.
case "${SHELL:-}" in
    *zsh)  PROFILE="$HOME/.zshrc" ;;
    *bash) PROFILE="$HOME/.bashrc" ;;
    *)     PROFILE="$HOME/.profile" ;;
esac

# Persist "export NAME=VALUE" in $PROFILE, replacing any existing line for NAME.
# Backs the profile up to <profile>.bak the first time it is edited per run.
set_profile_var() {
    _name="$1"; _value="$2"
    _line="export ${_name}=\"${_value}\""
    touch "$PROFILE"
    if grep -q "^export ${_name}=" "$PROFILE"; then
        cp "$PROFILE" "$PROFILE.bak"
        sed -i.tmp -E "s#^export ${_name}=.*#${_line}#" "$PROFILE" && rm -f "$PROFILE.tmp"
        ok "Updated ${_name} in $PROFILE (backup: $PROFILE.bak)"
    else
        printf '\n%s\n' "$_line" >> "$PROFILE"
        ok "Added ${_name} to $PROFILE"
    fi
}

open_url() {
    if command -v open >/dev/null 2>&1;      then open "$1"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1 || true
    else note "Open this URL manually: $1"; fi
}

# ===========================================================================
# 1) PACKAGE MANAGER (Homebrew)
# ===========================================================================
if [ "$SKIP_PKG_MANAGER" = false ]; then
    step "Package manager (Homebrew)"
    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew already installed - updating."
        brew update || warn "brew update failed; continuing."
    elif [ "$OS" = "Darwin" ] || [ "$OS" = "Linux" ]; then
        note "Installing Homebrew (you may be prompted for your password)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        ok "Homebrew installed."
    else
        warn "Unsupported OS for automatic Homebrew install. See https://brew.sh/"
    fi
else
    note "Skipping package manager step (--skip-package-manager)."
fi

# ===========================================================================
# 2) GOOSE
# ===========================================================================
if [ "$SKIP_GOOSE" = false ]; then
    step "Goose"
    note "The official docs cover the download/install for your OS."
    note "Opening: $GOOSE_DOCS_URL"
    open_url "$GOOSE_DOCS_URL"
    ok "Follow the download/install (or update) instructions there."
else
    note "Skipping Goose download step (--skip-goose)."
fi

# ===========================================================================
# 3) GOOSE CONTEXT / OUTPUT
# ===========================================================================
# On large-window models the default auto-compaction trigger (80% of the limit)
# can be hundreds of thousands of tokens. Long before that a session gets slow,
# costly, and less accurate. Setting both a tracked context limit and a lower
# threshold gives a predictable, earlier compaction point across all models.
#   trigger tokens = GOOSE_CONTEXT_LIMIT x GOOSE_AUTO_COMPACT_THRESHOLD
# Defaults 200000 x 0.7 = compact around 140000 tokens.
# GOOSE_MAX_TOOL_RESPONSE_SIZE caps a single tool result (in bytes) so one command
# - e.g. a whole-filesystem 'find /' - can't flood the context in a single turn.
if [ "$SKIP_CONTEXT" = false ]; then
    step "Goose context / output"
    set_profile_var "GOOSE_CONTEXT_LIMIT" "$CONTEXT_LIMIT"
    export GOOSE_CONTEXT_LIMIT="$CONTEXT_LIMIT"
    set_profile_var "GOOSE_AUTO_COMPACT_THRESHOLD" "$AUTO_COMPACT_THRESHOLD"
    export GOOSE_AUTO_COMPACT_THRESHOLD="$AUTO_COMPACT_THRESHOLD"
    set_profile_var "GOOSE_MAX_TOOL_RESPONSE_SIZE" "$MAX_TOOL_RESPONSE_SIZE"
    export GOOSE_MAX_TOOL_RESPONSE_SIZE="$MAX_TOOL_RESPONSE_SIZE"
    note "Open a new terminal (or 'source $PROFILE') and restart Goose to pick these up."
else
    note "Skipping Goose context settings (--skip-context)."
fi

# ===========================================================================
# 4) GLOBAL GOOSE HINTS (shell hygiene)
# ===========================================================================
# Goose loads ~/.config/goose/.goosehints into every session. These rules keep
# tool output small so a single command (e.g. a whole-filesystem 'find /') can't
# balloon the context and trigger empty-response errors from the model provider.
# Created only if absent, so your own custom hints are never overwritten.
if [ "$SKIP_HINTS" = false ]; then
    step "Global Goose hints"
    HINTS_FILE="$HOME/.config/goose/.goosehints"
    if [ -f "$HINTS_FILE" ]; then
        note "Hints already exist: $HINTS_FILE (left untouched)."
        note "See docs/goose-hints.md if you want to merge in the recommended rules."
    else
        mkdir -p "$(dirname "$HINTS_FILE")"
        cat > "$HINTS_FILE" <<'HINTS'
# Global Goose hints - apply to every session.
# See: goose-starter/docs/goose-hints.md

## Shell hygiene - keep tool output small
- Never scan from `/`. Scope searches to specific directories
  (e.g. the project dir, ~/.agents/skills, /mnt/skills).
- Cap long output: pipe through `head`/`tail`, and prefer counts
  (`wc -l`, `grep -c`) over full dumps.
- For file discovery use `rg --files -g PATTERN <dir>` instead of `find /`.
- Redirect large intermediate output to a temp file, then read only what you
  need: `cmd > /tmp/out.txt; wc -l /tmp/out.txt`.

## Secrets - never expose them
- Never print, echo, or `cat` secret files. This includes Goose's own
  `config.yaml` and `secrets.yaml`, plus `.env`, `*.pem`, and `*.key` files.
- When you must inspect such a file, redact values: show keys/structure only
  (e.g. `grep -c` or mask with `sed`), never the secret itself.
- Never write an API key, token, or password into a file, command, or commit.
  If a secret is needed, reference it by env-var name and let the keyring supply it.
HINTS
        ok "Wrote $HINTS_FILE"
        note "Restart Goose (or start a new session) to pick these up."
    fi
else
    note "Skipping global Goose hints (--skip-hints)."
fi

# ===========================================================================
# 5) GITHUB ENTERPRISE COPILOT (optional)
# ===========================================================================
if [ -n "$ENTERPRISE_HOST" ]; then
    step "GitHub Enterprise Copilot configuration"

    # 4a. Persist GITHUB_COPILOT_HOST in the shell profile.
    set_profile_var "GITHUB_COPILOT_HOST" "$ENTERPRISE_HOST"
    export GITHUB_COPILOT_HOST="$ENTERPRISE_HOST"
    note "Open a new terminal (or 'source $PROFILE') and restart Goose to pick it up."

    # 4b. Pin the default model in Goose's config.yaml.
    GOOSE_CFG="$HOME/.config/goose/config.yaml"
    if [ -z "$DEFAULT_MODEL" ]; then
        note "No --model given; skipping model pin."
    elif [ ! -f "$GOOSE_CFG" ]; then
        warn "Goose config not found: $GOOSE_CFG"
        warn "Launch Goose, connect the GitHub Copilot provider once, then re-run to pin the model."
    else
        cp "$GOOSE_CFG" "$GOOSE_CFG.bak"
        if command -v yq >/dev/null 2>&1; then
            yq -i ".active_provider = \"github_copilot\" | .providers.github_copilot.model = \"$DEFAULT_MODEL\"" "$GOOSE_CFG"
            ok "Pinned default model to '$DEFAULT_MODEL' in $GOOSE_CFG (backup: config.yaml.bak)"
        else
            warn "'yq' not found - cannot safely edit YAML automatically."
            warn "Add this to $GOOSE_CFG by hand (while Goose is closed):"
            printf '        active_provider: github_copilot\n'
            printf '        providers:\n          github_copilot:\n            model: %s\n' "$DEFAULT_MODEL"
            note "Tip: install yq with 'brew install yq' and re-run to automate this."
        fi
    fi
fi

# ===========================================================================
# MANUAL STEPS
# ===========================================================================
step "Manual steps to finish"
cat <<EOF
  1. Install/update Goose from the page that just opened ($GOOSE_DOCS_URL).
  2. Launch Goose.
EOF
if [ -n "$ENTERPRISE_HOST" ]; then
cat <<EOF
  3. Restart your terminal/Goose so GITHUB_COPILOT_HOST takes effect.
  4. Provider settings -> GitHub Copilot -> run the device-flow sign-in.
     - It should send you to https://$ENTERPRISE_HOST/login/device
     - Sign in with your managed enterprise account.
     - Or use the CLI: 'goose configure' (honours GITHUB_COPILOT_HOST).
  5. In the model picker choose your model (not 'Auto') so the default sticks.
EOF
fi
printf '\nDone.\n'
