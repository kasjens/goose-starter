#!/usr/bin/env bash
#
# install.sh — set up (or update) your machine for Goose on macOS / Linux.
#
# What it automates:
#   1. Installs Homebrew (macOS) if missing, or updates it if present.
#   2. Opens the official Goose download page so you can install/update Goose.
#   3. (Optional) Configures Goose for a company GitHub Enterprise Copilot seat:
#        - sets GITHUB_COPILOT_HOST in your shell profile
#        - pins a default Copilot model in Goose's config.yaml
#
# What it CANNOT do (interactive, must be done by hand):
#   - The Goose Copilot device-flow sign-in. Manual steps are printed at the end.
#
# Re-runnable and idempotent. Every file it edits is backed up to "<file>.bak".
#
# Usage:
#   ./install.sh                                  # package manager + Goose only
#   ./install.sh --enterprise-host your-co.ghe.com --model claude-opus-4.8
#   ./install.sh --skip-goose                     # only configure, don't open download page
#
set -euo pipefail

# ---- defaults --------------------------------------------------------------
ENTERPRISE_HOST=""
DEFAULT_MODEL="claude-opus-4.8"
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
note "Enterprise host: ${ENTERPRISE_HOST:-'(none — public github.com)'}"
note "Default model  : ${DEFAULT_MODEL:-'(skip)'}"

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
        ok "Homebrew already installed — updating."
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
# 3) GITHUB ENTERPRISE COPILOT (optional)
# ===========================================================================
if [ -n "$ENTERPRISE_HOST" ]; then
    step "GitHub Enterprise Copilot configuration"

    # 3a. Persist GITHUB_COPILOT_HOST in the shell profile.
    case "${SHELL:-}" in
        *zsh)  PROFILE="$HOME/.zshrc" ;;
        *bash) PROFILE="$HOME/.bashrc" ;;
        *)     PROFILE="$HOME/.profile" ;;
    esac
    LINE="export GITHUB_COPILOT_HOST=\"$ENTERPRISE_HOST\""
    touch "$PROFILE"
    if grep -q '^export GITHUB_COPILOT_HOST=' "$PROFILE"; then
        cp "$PROFILE" "$PROFILE.bak"
        sed -i.tmp -E "s#^export GITHUB_COPILOT_HOST=.*#$LINE#" "$PROFILE" && rm -f "$PROFILE.tmp"
        ok "Updated GITHUB_COPILOT_HOST in $PROFILE (backup: $PROFILE.bak)"
    else
        printf '\n%s\n' "$LINE" >> "$PROFILE"
        ok "Added GITHUB_COPILOT_HOST to $PROFILE"
    fi
    export GITHUB_COPILOT_HOST="$ENTERPRISE_HOST"
    note "Open a new terminal (or 'source $PROFILE') and restart Goose to pick it up."

    # 3b. Pin the default model in Goose's config.yaml.
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
            warn "'yq' not found — cannot safely edit YAML automatically."
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
