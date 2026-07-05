# Securing Extension Secrets (API Keys)

Some Goose extensions need an API key or token to work - for example the Brave
Search extension needs a `BRAVE_API_KEY`. If you added the extension by pasting
the key straight in, that key can end up sitting in **plaintext** inside your
`config.yaml`. This guide shows how to move it into the system **keyring** so it
is stored securely.

> **Rule of thumb (straight from the Goose docs):** *avoid storing sensitive
> information (API keys, tokens) in the config file; use the system keyring for
> storing secrets.*

## How to tell if your key is exposed

Open `~/.config/goose/config.yaml` (macOS/Linux) or
`%APPDATA%\Block\goose\config\config.yaml` (Windows) and look at the extension.
A key stored insecurely looks like this - notice the real value appears in the
`envs` block (and sometimes duplicated as a command-line argument):

```yaml
  bravesearch:
    type: stdio
    cmd: npx
    args:
    - -y
    - '@brave/brave-search-mcp-server'
    - --brave-api-key
    - BSAxxxxxxxxxxxxxxxxxxxx     # plaintext copy #1 (command arg)
    enabled: true
    envs:
      BRAVE_API_KEY: BSAxxxxxxxxxxxxxxxxxxxx   # plaintext copy #2 (env value)
    timeout: 300
```

You can check quickly from a terminal (replace `brave` with your extension name):

```bash
grep -i brave ~/.config/goose/config.yaml
```

If you can see the key itself, it is exposed and should be secured.

## The key idea: `envs` vs `env_keys`

Goose's extension schema has two related fields, and the difference is the whole
point of this guide:

| Field | What it holds | Stored where |
| --- | --- | --- |
| `envs` | Environment **values**, written directly into `config.yaml` | Plaintext, in the file |
| `env_keys` | The **names** of environment variables the extension needs | Value comes from the secure keyring, not the file |

So securing a key means: stop putting the value in `envs`, and instead declare
the variable **name** in `env_keys`. Goose then pulls the value from the keyring
at runtime.

## Step 1 - Rotate the key first

If the key has been sitting in plaintext, treat it as compromised. It may also be
in your `config.yaml` **backups** (`config.yaml.bak*`) and your shell history.
Generate a **new** key in your provider's dashboard and revoke the old one before
doing anything else. There is no point hiding a key that has already leaked.

## Step 2 - Point the extension at the keyring

Edit the extension block so it references the variable by name instead of
embedding the value. Using Brave Search as the example:

```yaml
  bravesearch:
    name: bravesearch
    display_name: Brave Search
    description: Web search via the Brave Search API
    type: stdio
    cmd: npx
    args:
    - -y
    - '@brave/brave-search-mcp-server'
    enabled: true
    env_keys:
    - BRAVE_API_KEY
    timeout: 300
    bundled: false
```

What changed:

- Removed the plaintext value (and the `--brave-api-key` argument that repeated it)
  from `args`.
- Removed the whole `envs:` block.
- Added `env_keys: [BRAVE_API_KEY]` so Goose injects the value from the keyring.

> **Note:** Dropping the `--brave-api-key` flag works because the Brave MCP server
> reads the key from the `BRAVE_API_KEY` environment variable. That behavior
> belongs to the extension (MCP server), not to Goose - confirm it in the
> extension's own README before removing a command-line flag.

## Step 3 - Store the real key in the keyring

Goose stores an extension secret in the system keyring through its
**extension-secrets** flow (CLI). When an extension declares `env_keys` and the
value is **missing from the keyring**, Goose prompts you for it and then stores it
securely, reusing it on later runs.

Run:

```bash
goose configure
```

and add / update the extension's environment variable through the **Add
Extension** flow. When Goose asks *"Would you like to add environment
variables?"*, choose **Yes**, enter the name (`BRAVE_API_KEY`) and paste your
**new** key as the value. The value goes into the keyring, not the file.

## Step 4 - Verify nothing is left in plaintext

```bash
goose info -v                                 # shows active config and paths
grep -i brave ~/.config/goose/config.yaml     # should show env_keys, NOT the key
```

You should see `env_keys: [BRAVE_API_KEY]` and **no** key value anywhere in the
file.

## Step 5 - Clean up old copies

Scrub any backups that still contain the old key. Because you rotated in Step 1
they are no longer a live risk, but they should not linger:

```bash
grep -l BSA ~/.config/goose/config.yaml.bak*   # find backups holding the old key
```

Delete or overwrite the ones that match.

## Important caveats

- **Changing the key later:** remove it from the system keyring, then re-run
  `goose configure` so Goose re-prompts. Editing the file alone will **not**
  update the stored secret.
- **No keyring available:** on headless servers, containers, CI, or when
  `GOOSE_DISABLE_KEYRING` is set, Goose falls back to a separate
  `secrets.yaml` file (`~/.config/goose/secrets.yaml`, or
  `%APPDATA%\Block\goose\config\secrets.yaml` on Windows). That file is still
  **plaintext** - it just keeps the secret out of `config.yaml`. Protect it with
  file permissions and keep it out of version control.
- **Environment variables win:** a value exported in your shell environment takes
  precedence over the config file, so make sure you are not also exporting the key
  somewhere.

## Quick checklist

- [ ] Key rotated (old one revoked) before doing anything else
- [ ] Plaintext value removed from `args` and `envs` in `config.yaml`
- [ ] `env_keys: [BRAVE_API_KEY]` added to the extension
- [ ] New key entered via `goose configure` (stored in the keyring)
- [ ] `grep -i brave config.yaml` shows `env_keys`, not the key value
- [ ] Old key scrubbed from `config.yaml.bak*` backups

## Sources

Verified against the official Goose documentation:

- [Configuration Files](https://goose-docs.ai/docs/guides/config-files) - security
  considerations, extension schema (`envs` vs `env_keys`), keyring vs
  `secrets.yaml`, `goose info -v`.
- [Environment Variables](https://goose-docs.ai/docs/guides/environment-variables) -
  `GOOSE_DISABLE_KEYRING`, `secrets.yaml` fallback locations, "use the keyring for
  API keys".
- [Using Extensions](https://goose-docs.ai/docs/getting-started/using-extensions) -
  `goose configure` flow and adding environment variables.
- [Recipe Reference Guide](https://goose-docs.ai/docs/guides/recipes/recipe-reference) -
  Extension Secrets (prompt-and-store-in-keyring behavior).
