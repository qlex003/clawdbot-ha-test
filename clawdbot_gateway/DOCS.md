# Clawdbot Gateway Documentation

This add-on runs the Clawdbot Gateway on Home Assistant OS, with optional secure remote access via SSH (tunnel/CLI).

## Overview

- **Gateway** runs locally on the HA host (binds to loopback by default)
- **Optional: SSH server (Key-based)** provides secure remote access for Debug/CLI (standardmäßig aus)
- **Persistent storage** under `/config/clawdbot` survives add-on updates
- On first start, runs `clawdbot setup` to create a minimal config

## Installation

1. In Home Assistant: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Add: `https://github.com/Al3xand3r1987/clawdbot-ha`
3. Reload the Add-on Store and install **Clawdbot Gateway**

## Configuration

### Add-on Options

| Option | Description |
|--------|-------------|
| `easy_setup_ui` | If enabled: exposes a simple setup page at `/__setup/` in the Ingress UI (no SSH needed) |
| `ssh_authorized_keys` | (Optional) Your public key(s) for SSH access. If empty: SSH is disabled. Required for SSH tunnel/CLI access. |
| `ssh_port` | SSH server port (default: `2222`, only relevant if SSH is enabled) |
| `port` | Gateway WebSocket port (default: `18789`) |
| `repo_url` | Clawdbot source repository URL |
| `branch` | Branch to checkout (uses repo's default if omitted) |
| `github_token` | Token for private repository access |
| `verbose` | Enable verbose logging |
| `log_format` | Log output format in the add-on Log tab: `pretty` or `raw` |
| `log_color` | Enable ANSI colors for pretty logs (may be ignored in the UI) |
| `log_fields` | Comma-separated metadata keys to append (e.g. `connectionId,uptimeMs,runId`) |

### First Run

The add-on performs these steps on startup:

1. Clones or updates the Clawdbot repo into `/config/clawdbot/source/clawdbot-src`
2. Installs dependencies and builds the gateway
3. Runs `clawdbot setup` if no config exists
4. Ensures `gateway.mode=local` if missing
5. Starts the gateway

### Clawdbot Configuration

SSH into the add-on and run the configurator.

Note: SSH is only available if `ssh_authorized_keys` is set in the add-on options.

```bash
ssh -p 2222 root@<ha-host>
cd /config/clawdbot/source/active
pnpm clawdbot onboard
```

Or use the shorter flow:

```bash
pnpm clawdbot configure
```

The gateway auto-reloads config changes. Restart the add-on only if you change SSH keys or build settings:

```bash
ha addons restart local_clawdbot
```

### OAuth / API-Key Setup ohne SSH (Ingress)

Wenn du **kein SSH** nutzen willst (z. B. „ChatGPT/Codex OAuth“ statt API-Key), kannst du das Setup direkt über die Home-Assistant Oberfläche machen:

1. In den Add-on Optionen `easy_setup_ui: true` setzen und das Add-on neu starten
2. Add-ons → **Clawdbot Gateway** → **OPEN WEB UI**
3. Öffne die Setup-Seite:
   - Wenn noch keine Konfiguration existiert: sie erscheint automatisch
   - Sonst: rufe `/__setup/` auf
4. Dort:
   - **Wizard starten** (empfohlen) → wähle „OpenAI Codex (ChatGPT OAuth)“ oder setze API Keys
   - Optional: API Keys werden nach `/config/clawdbot/data/state/.env` geschrieben

Hinweis: OAuth-Tokens werden von Clawdbot automatisch refreshed. Ein manueller Re-Login ist nur nötig, wenn der Provider die Session invalidiert.

## Usage

### SSH Tunnel Access

The gateway listens on loopback by default. Access it via SSH tunnel:

Note: Requires SSH enabled via `ssh_authorized_keys` in the add-on options.

```bash
ssh -p 2222 -N -L 18789:127.0.0.1:18789 root@<ha-host>
```

Then point Clawdbot.app or the CLI at `ws://127.0.0.1:18789`.

### Bind Mode

Configure bind mode via the Clawdbot CLI (over SSH), not in the add-on options.
Use `pnpm clawdbot configure` or `pnpm clawdbot onboard` to set it in `clawdbot.json`.

## Data Locations

| Path | Description |
|------|-------------|
| `/config/clawdbot/data/clawdbot.json` | Main configuration |
| `/config/clawdbot/data/state/` | State data (inkl. Tokens, z. B. `agent/auth.json`) |
| `/config/clawdbot/data/workspace` | Agent workspace |
| `/config/clawdbot/source/clawdbot-src` | Source repository (für Builds/Updates) |
| `/config/clawdbot/source/active` | Aktive Version (Symlink auf Cache) |
| `/config/clawdbot/cache/` | Gebaute Versionen (für Rollback & Snapshots) |
| `/config/clawdbot/.ssh` | SSH keys |
| `/config/clawdbot/.config` | App configs (gh, etc.) |

## Included Tools

- **gog** — Google Workspace CLI ([gogcli.sh](https://gogcli.sh))
- **gh** — GitHub CLI ([cli.github.com](https://cli.github.com))
- **clawdhub** — Skill marketplace CLI
- **hass-cli** — Home Assistant CLI

## Troubleshooting

### SSH doesn't work
Ensure `ssh_authorized_keys` is set in the add-on options with your public key.

### Gateway won't start
Check logs:
```bash
ha addons logs local_clawdbot -n 200
```

### Build takes too long
The first boot runs a full build and may take several minutes. Subsequent starts are faster.

## Security Notes

- For `bind=lan/tailnet/auto`, enable gateway auth in `clawdbot.json`
- The add-on uses host networking for SSH access
- Consider firewall rules for the SSH port if exposed to LAN

## Links

- [Clawdbot](https://github.com/clawdbot/clawdbot) — Main repository
- [Documentation](https://docs.clawd.bot) — Full documentation
- [Community](https://discord.com/invite/clawd) — Discord server
- [gog CLI](https://gogcli.sh) — Google Workspace CLI
- [GitHub CLI](https://cli.github.com) — GitHub CLI
