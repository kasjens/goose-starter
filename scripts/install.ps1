<#
.SYNOPSIS
    Set up (or update) your machine for Goose on Windows.

.DESCRIPTION
    Idempotent, re-runnable setup that automates the docs' install steps:

      1. Installs Scoop if missing, or updates it if already present.
      2. Opens the official Goose download page so you can install/update Goose.
      3. Sets Goose context / output env vars so long sessions compact earlier and
         no single tool call floods the context
         (GOOSE_CONTEXT_LIMIT + GOOSE_AUTO_COMPACT_THRESHOLD + GOOSE_MAX_TOOL_RESPONSE_SIZE).
      4. Writes a global .goosehints with shell-hygiene rules so Goose keeps tool
         output small (no whole-filesystem scans, cap output, etc).
      5. (Optional) Configures Goose for a company GitHub Enterprise Copilot seat:
           - sets the GITHUB_COPILOT_HOST user env var
           - pins a default Copilot model in Goose's config.yaml

    What it CANNOT do (interactive OAuth cannot be scripted):
      * The Goose Copilot device-flow sign-in. Manual steps are printed at the end.

    Every file this script edits is copied to "<file>.bak" first.

.PARAMETER EnterpriseHost
    Your GitHub Enterprise host, e.g. your-company.ghe.com (scheme/trailing slash stripped).
    Leave blank to skip enterprise Copilot configuration (uses public github.com).

.PARAMETER DefaultModel
    The Goose default Copilot model id (decimal ids, e.g. claude-opus-4.8). Blank = skip pinning.

.PARAMETER ContextLimit
    Tokens to set as GOOSE_CONTEXT_LIMIT (the tracked context window). Default 200000.

.PARAMETER AutoCompactThreshold
    Fraction (0.0-1.0) to set as GOOSE_AUTO_COMPACT_THRESHOLD; auto-compaction fires at
    ContextLimit x this value. Default 0.7 (with the default limit, ~140000 tokens). 0.0 disables.

.PARAMETER MaxToolResponseSize
    Bytes to set as GOOSE_MAX_TOOL_RESPONSE_SIZE - caps a single tool result so one
    command can't flood the context in a turn. Default 50000.

.PARAMETER SkipContext
    Skip setting the Goose context / output env vars.

.PARAMETER SkipHints
    Skip writing the global .goosehints shell-hygiene file.

.PARAMETER SkipPackageManager
    Skip installing/updating Scoop.

.PARAMETER SkipGoose
    Skip opening the Goose download page.

.EXAMPLE
    ./install.ps1

.EXAMPLE
    ./install.ps1 -EnterpriseHost your-company.ghe.com -DefaultModel claude-opus-4.8

.EXAMPLE
    ./install.ps1 -ContextLimit 150000 -AutoCompactThreshold 0.8
#>
[CmdletBinding()]
param(
    [string]$EnterpriseHost = '',
    [string]$DefaultModel   = 'claude-opus-4.8',
    [int]$ContextLimit      = 200000,
    [double]$AutoCompactThreshold = 0.7,
    [int]$MaxToolResponseSize = 50000,
    [switch]$SkipContext,
    [switch]$SkipHints,
    [switch]$SkipPackageManager,
    [switch]$SkipGoose
)

$ErrorActionPreference = 'Stop'
$GooseDocsUrl = 'https://goose-docs.ai/'

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    [OK]  $m" -ForegroundColor Green }
function Write-Note($m) { Write-Host "    [--] $m" -ForegroundColor Gray }
function Write-Warn2($m){ Write-Host "    [!]  $m" -ForegroundColor Yellow }

function Save-Utf8NoBom($Path, $Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# Normalise host: strip scheme + trailing slash
$EnterpriseHost = ($EnterpriseHost -replace '^https?://', '').TrimEnd('/')

Write-Host "Goose setup (Windows)" -ForegroundColor White
Write-Note "Enterprise host: $(if ($EnterpriseHost) { $EnterpriseHost } else { '(none - public github.com)' })"
Write-Note "Default model  : $(if ($DefaultModel) { $DefaultModel } else { '(skip)' })"
Write-Note "Context        : $(if ($SkipContext) { '(skip)' } else { "limit $ContextLimit, threshold $AutoCompactThreshold, max tool output $MaxToolResponseSize bytes" })"

# ===========================================================================
# 1) PACKAGE MANAGER (Scoop)
# ===========================================================================
if (-not $SkipPackageManager) {
    Write-Step "Package manager (Scoop)"
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Ok "Scoop already installed - updating."
        try { scoop update } catch { Write-Warn2 "scoop update failed; continuing." }
    }
    else {
        Write-Note "Installing Scoop..."
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        Write-Ok "Scoop installed."
    }
}
else {
    Write-Note "Skipping package manager step (-SkipPackageManager)."
}

# ===========================================================================
# 2) GOOSE
# ===========================================================================
if (-not $SkipGoose) {
    Write-Step "Goose"
    Write-Note "The official docs cover the download/install for Windows."
    Write-Note "Opening: $GooseDocsUrl"
    Start-Process $GooseDocsUrl
    Write-Ok "Follow the download/install (or update) instructions there."
}
else {
    Write-Note "Skipping Goose download step (-SkipGoose)."
}

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
# - e.g. a whole-filesystem scan - can't flood the context in a single turn.
if (-not $SkipContext) {
    Write-Step "Goose context / output"

    [Environment]::SetEnvironmentVariable('GOOSE_CONTEXT_LIMIT', "$ContextLimit", 'User')
    $env:GOOSE_CONTEXT_LIMIT = "$ContextLimit"
    Write-Ok "Set user env var GOOSE_CONTEXT_LIMIT = $ContextLimit"

    $thr = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $AutoCompactThreshold)
    [Environment]::SetEnvironmentVariable('GOOSE_AUTO_COMPACT_THRESHOLD', $thr, 'User')
    $env:GOOSE_AUTO_COMPACT_THRESHOLD = $thr
    if ($AutoCompactThreshold -le 0) {
        Write-Ok "Set user env var GOOSE_AUTO_COMPACT_THRESHOLD = $thr (auto-compaction disabled)"
    }
    else {
        $trigger = [int]($ContextLimit * $AutoCompactThreshold)
        Write-Ok "Set user env var GOOSE_AUTO_COMPACT_THRESHOLD = $thr (compacts around $trigger tokens)"
    }

    [Environment]::SetEnvironmentVariable('GOOSE_MAX_TOOL_RESPONSE_SIZE', "$MaxToolResponseSize", 'User')
    $env:GOOSE_MAX_TOOL_RESPONSE_SIZE = "$MaxToolResponseSize"
    Write-Ok "Set user env var GOOSE_MAX_TOOL_RESPONSE_SIZE = $MaxToolResponseSize (bytes per tool result)"

    Write-Note "Restart Goose (and open a new terminal for the CLI) to pick these up."
}
else {
    Write-Note "Skipping Goose context settings (-SkipContext)."
}

# ===========================================================================
# 4) GLOBAL GOOSE HINTS (shell hygiene)
# ===========================================================================
# Goose loads .goosehints from its config dir into every session. These rules keep
# tool output small so a single command (e.g. a whole-filesystem scan) can't
# balloon the context and trigger empty-response errors from the model provider.
# Created only if absent, so your own custom hints are never overwritten.
if (-not $SkipHints) {
    Write-Step "Global Goose hints"
    $hintsFile = Join-Path $env:APPDATA 'Block\goose\config\.goosehints'
    if (Test-Path $hintsFile) {
        Write-Note "Hints already exist: $hintsFile (left untouched)."
        Write-Note "See docs/goose-hints.md if you want to merge in the recommended rules."
    }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $hintsFile) | Out-Null
        $hints = @"
# Global Goose hints - apply to every session.
# See: goose-starter/docs/goose-hints.md

## Shell hygiene - keep tool output small
- Never scan from ``/``. Scope searches to specific directories
  (e.g. the project dir, ~/.agents/skills, /mnt/skills).
- Cap long output: pipe through ``head``/``tail``, and prefer counts
  (``wc -l``, ``grep -c``) over full dumps.
- For file discovery use ``rg --files -g PATTERN <dir>`` instead of ``find /``.
- Redirect large intermediate output to a temp file, then read only what you
  need: ``cmd > /tmp/out.txt; wc -l /tmp/out.txt``.

## Secrets - never expose them
- Never print, echo, or ``cat`` secret files. This includes Goose's own
  ``config.yaml`` and ``secrets.yaml``, plus ``.env``, ``*.pem``, and ``*.key`` files.
- When you must inspect such a file, redact values: show keys/structure only
  (e.g. ``grep -c`` or mask with ``sed``), never the secret itself.
- Never write an API key, token, or password into a file, command, or commit.
  If a secret is needed, reference it by env-var name and let the keyring supply it.
"@
        Save-Utf8NoBom $hintsFile $hints
        Write-Ok "Wrote $hintsFile"
        Write-Note "Restart Goose (or start a new session) to pick these up."
    }
}
else {
    Write-Note "Skipping global Goose hints (-SkipHints)."
}

# ===========================================================================
# 5) GITHUB ENTERPRISE COPILOT (optional)
# ===========================================================================
if ($EnterpriseHost) {
    Write-Step "GitHub Enterprise Copilot configuration"

    # 4a. Persist GITHUB_COPILOT_HOST (user scope) before the first sign-in.
    [Environment]::SetEnvironmentVariable('GITHUB_COPILOT_HOST', $EnterpriseHost, 'User')
    $env:GITHUB_COPILOT_HOST = $EnterpriseHost
    Write-Ok "Set user env var GITHUB_COPILOT_HOST = $EnterpriseHost (restart Goose to pick it up)"

    # 4b. Pin the default model in Goose's config.yaml.
    $gooseCfg = Join-Path $env:APPDATA 'Block\goose\config\config.yaml'

    if ([string]::IsNullOrWhiteSpace($DefaultModel)) {
        Write-Note "No -DefaultModel given; skipping model pin."
    }
    elseif (-not (Test-Path $gooseCfg)) {
        Write-Warn2 "Goose config not found: $gooseCfg"
        Write-Warn2 "Launch Goose, connect the GitHub Copilot provider once, then re-run to pin the model."
    }
    else {
        # Goose rewrites config.yaml on exit with the last-used model, so close it while editing.
        $gp = Get-Process -Name Goose -ErrorAction SilentlyContinue
        if ($gp) {
            Write-Warn2 "Goose is running - closing it so the edit is not overwritten on exit..."
            $gp | Stop-Process -Force
            Start-Sleep -Milliseconds 800
        }

        Copy-Item $gooseCfg "$gooseCfg.bak" -Force
        $content = Get-Content -Raw $gooseCfg
        $nl    = if ($content -match "`r`n") { "`r`n" } else { "`n" }
        $lines = [System.Collections.Generic.List[string]]($content -split "`r?`n")

        # active_provider: github_copilot
        $apFound = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*active_provider\s*:') { $lines[$i] = 'active_provider: github_copilot'; $apFound = $true; break }
        }
        if (-not $apFound) { $lines.Add('active_provider: github_copilot') }

        # providers.github_copilot.model: <DefaultModel>
        $ghcIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*github_copilot\s*:\s*$') { $ghcIdx = $i; break }
        }
        if ($ghcIdx -ge 0) {
            $ghcIndent   = ($lines[$ghcIdx] -replace '\S.*$', '')
            $childIndent = $ghcIndent + '  '
            $modelIdx    = -1
            $j = $ghcIdx + 1
            while ($j -lt $lines.Count) {
                $lj = $lines[$j]
                if ($lj.Trim() -eq '') { $j++; continue }
                $indent = ($lj -replace '\S.*$', '')
                if ($indent.Length -le $ghcIndent.Length) { break }
                if ($lj -match '^\s*model\s*:') { $modelIdx = $j; break }
                $j++
            }
            if ($modelIdx -ge 0) { $lines[$modelIdx] = "${childIndent}model: $DefaultModel" }
            else                 { $lines.Insert($ghcIdx + 1, "${childIndent}model: $DefaultModel") }
        }
        else {
            $hasProviders = $false
            foreach ($l in $lines) { if ($l -match '^\s*providers\s*:\s*$') { $hasProviders = $true; break } }
            if (-not $hasProviders) { $lines.Add('providers:') }
            $lines.Add('  github_copilot:')
            $lines.Add('    enabled: true')
            $lines.Add("    model: $DefaultModel")
            $lines.Add('    configured: true')
        }

        Save-Utf8NoBom $gooseCfg (($lines -join $nl).TrimEnd("`r","`n") + $nl)
        Write-Ok "Pinned Goose default model to '$DefaultModel' (backup: config.yaml.bak)"
    }
}

# ===========================================================================
# MANUAL STEPS
# ===========================================================================
Write-Step "Manual steps to finish"
$manual = @"
  1. Install/update Goose from the page that just opened ($GooseDocsUrl).
  2. Launch Goose.
"@
if ($EnterpriseHost) {
    $manual += @"

  3. Fully quit and relaunch Goose so it reads GITHUB_COPILOT_HOST.
  4. Provider settings -> GitHub Copilot -> run the device-flow sign-in.
     - It should send you to https://$EnterpriseHost/login/device
     - Sign in with your managed enterprise account.
     - Or use the CLI: 'goose configure' (honours GITHUB_COPILOT_HOST).
  5. In the model picker choose your model (NOT 'Auto') so the default sticks.
"@
}
Write-Host $manual -ForegroundColor White
Write-Host "`nDone." -ForegroundColor Green
