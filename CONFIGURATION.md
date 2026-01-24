# Clawdbot HA Add-on - Configuration Guide

Complete reference for all configuration options in the Clawdbot Home Assistant Add-on.

---

## Configuration Overview

The Clawdbot add-on can be configured in three ways:

1. **Add-on Configuration Tab** (Home Assistant UI) - For add-on-specific settings
2. **Clawdbot Config File** (`/config/clawdbot/data/clawdbot.json`) - For Clawdbot-specific settings
3. **Environment Variables** (Advanced) - For runtime customization

---

## Add-on Configuration Options

These options are configured in the **Add-on Configuration Tab** in Home Assistant.

### Core Options

#### `easy_setup_ui`
- **Type:** `boolean`
- **Default:** `false`
- **Description:** Aktiviert eine einfache Setup-Seite im Home-Assistant Ingress unter `/__setup/` (OAuth/API Keys ohne SSH)
- **Use Case:** ChatGPT/Codex OAuth einrichten oder Keys setzen, ohne in den Container zu müssen

```yaml
easy_setup_ui: true
```

#### `ssh_port`
- **Type:** `integer`
- **Default:** `2222`
- **Range:** `1024-65535`
- **Description:** Port for SSH access (nur relevant wenn SSH aktiv)

```yaml
ssh_port: 2222
```

#### `ssh_authorized_keys`
- **Type:** `string`
- **Default:** `""`
- **Description:** Öffentliche SSH Keys (wenn leer: SSH ist deaktiviert)
- **Security:** Nur **Key-based** (keine Passwörter)

```yaml
ssh_authorized_keys: "ssh-ed25519 AAAA... user@host"
```

---

### Update Options

#### `update_mode`
- **Type:** `list(disabled|notify|stable|latest)`
- **Default:** `stable`
- **Description:** How the add-on handles Clawdbot updates

**Modes:**

| Mode | Behavior | Use Case |
|------|----------|----------|
| `disabled` | No automatic updates | Manual control only |
| `notify` | Notify when update available | User approval required |
| `stable` | Auto-update to stable releases | **Recommended for production** |
| `latest` | Auto-update including pre-releases | Testing and early adopters |

```yaml
update_mode: stable
```

**Examples:**

```yaml
# Production (recommended)
update_mode: stable

# Conservative
update_mode: notify

# Testing
update_mode: latest

# Manual only
update_mode: disabled
```

#### `pinned_version`
- **Type:** `string`
- **Default:** `""`
- **Description:** Pin to a specific Clawdbot version (overrides `update_mode`)
- **Format:** Git tag or commit hash (e.g., `v2026.1.24`, `abc1234`)

```yaml
pinned_version: "v2026.1.24"
```

**Use Cases:**
- Stick to a known-good version
- Prevent automatic updates
- Test specific versions

#### `auto_cleanup_versions`
- **Type:** `boolean`
- **Default:** `true`
- **Description:** Automatically remove old cached versions

```yaml
auto_cleanup_versions: true
```

#### `max_cached_versions`
- **Type:** `integer`
- **Default:** `2`
- **Range:** `1-10`
- **Description:** Maximum number of versions to keep cached
- **Disk Usage:** ~200-400MB per version

```yaml
max_cached_versions: 2
```

**Recommendations:**
- `2`: Minimum (current + 1 rollback) - ~400MB
- `3`: Good balance (current + 2 rollbacks) - ~600MB
- `5+`: For extensive version history - ~1GB+

---

### API & Integration / Advanced

Diese Einstellungen werden **nicht** als Add-on Optionen konfiguriert, sondern in der **Clawdbot Konfig** (`/config/clawdbot/data/clawdbot.json`) oder über die Web UI:

- Anthropic API Key / Model
- Telegram/WhatsApp Integrationen

---

## Clawdbot Configuration File

The main Clawdbot configuration is stored in:
```
/config/clawdbot/data/clawdbot.json
```

### Accessing the Config File

#### Via SSH
```bash
ssh -p 2222 root@YOUR-HA-IP
cd /config/clawdbot/data
nano clawdbot.json
```

**Hinweis:** SSH ist optional und läuft nur, wenn `ssh_authorized_keys` in der Add-on Konfiguration gesetzt ist.

#### Via File Editor Add-on
1. Install **File Editor** add-on
2. Navigate to `/config/clawdbot/data/clawdbot.json`
3. Edit and save

### Configuration Structure

```json
{
  "anthropic_api_key": "sk-ant-api03-your-key-here",
  "model": "claude-sonnet-4.5",
  "max_tokens": 8192,
  "temperature": 0.7,
  "telegram": {
    "enabled": true,
    "bot_token": "123456789:ABC...",
    "allowed_users": [123456789]
  },
  "whatsapp": {
    "enabled": false,
    "phone_number": ""
  },
  "skills": {
    "enabled": true,
    "auto_update": true,
    "allowed_skills": ["*"]
  },
  "workspace": {
    "path": "/config/clawdbot/data/workspace",
    "max_size_mb": 500
  }
}
```

### Key Settings

#### Anthropic API

```json
{
  "anthropic_api_key": "sk-ant-api03-...",
  "model": "claude-sonnet-4.5",
  "max_tokens": 8192,
  "temperature": 0.7
}
```

**Models:**
- `claude-opus-4.5`: Most capable (higher cost)
- `claude-sonnet-4.5`: Balanced (recommended)
- `claude-haiku-4.0`: Fast and efficient

#### Telegram Integration

```json
{
  "telegram": {
    "enabled": true,
    "bot_token": "YOUR-BOT-TOKEN",
    "allowed_users": [123456789, 987654321],
    "max_message_length": 4096
  }
}
```

**Setup Steps:**
1. Create bot via [@BotFather](https://t.me/BotFather)
2. Get your user ID via [@userinfobot](https://t.me/userinfobot)
3. Add to `allowed_users`
4. Restart Clawdbot

#### WhatsApp Integration

```json
{
  "whatsapp": {
    "enabled": true,
    "phone_number": "+1234567890",
    "qr_code_timeout": 60
  }
}
```

**Note:** Requires phone pairing on first use.

#### Skills Configuration

```json
{
  "skills": {
    "enabled": true,
    "auto_update": true,
    "allowed_skills": ["*"],
    "disabled_skills": ["dangerous-skill"]
  }
}
```

---

## Update Modes Detailed

### `disabled` Mode
**Use Case:** Complete manual control

```yaml
update_mode: disabled
```

**Behavior:**
- No automatic updates
- No update checks
- Current version stays active
- Manual update via pinned_version

**When to use:**
- Critical production systems
- Testing custom modifications
- Known-good version deployed

---

### `notify` Mode
**Use Case:** Approval-based updates

```yaml
update_mode: notify
```

**Behavior:**
- Checks for updates
- Sends Home Assistant notification
- Waits for user approval
- No automatic installation

**Notification Example:**
```
Clawdbot Update Available
Version v2026.1.25 is available.
Current: v2026.1.24

To update, set pinned_version: "v2026.1.25"
```

**When to use:**
- Conservative update strategy
- Review changelogs before updating
- Scheduled maintenance windows

---

### `stable` Mode (Recommended)
**Use Case:** Automatic stable updates

```yaml
update_mode: stable
```

**Behavior:**
- Auto-checks for updates
- Only stable releases (no alpha/beta/rc)
- Downloads and builds in background
- Smoke-tests before activation
- Auto-rollback on failure

**Update Process:**
1. New stable version detected
2. Downloaded in isolation
3. Built and tested
4. Activated if tests pass
5. Old version kept as rollback

**When to use:**
- Production systems (recommended)
- Balance of stability and updates
- Minimal maintenance

---

### `latest` Mode
**Use Case:** Early adopter / testing

```yaml
update_mode: latest
```

**Behavior:**
- Includes pre-releases (alpha, beta, rc)
- Faster access to new features
- Higher risk of bugs
- Same safety mechanisms as stable

**When to use:**
- Testing environments
- Early feature access
- Contributing to development

---

## Version Management

### Pinning a Specific Version

```yaml
update_mode: stable
pinned_version: "v2026.1.24"
```

**How it works:**
- Overrides `update_mode`
- Downloads and activates specified version
- Stays pinned until changed

**Rollback to Previous Version:**
```yaml
# Check available cached versions
ssh -p 2222 root@YOUR-HA-IP
ls /config/clawdbot/cache/

# Pin to previous version
pinned_version: "v2026.1.23"
```

### Cached Versions

Cached versions are stored in:
```
/config/clawdbot/cache/
├── v2026.1.24/  # Current
├── v2026.1.23/  # Previous (rollback available)
```

**Benefits:**
- Instant rollback (no rebuild)
- Faster updates (no re-download)
- Included in snapshots

**Management:**
```yaml
max_cached_versions: 2  # Keep 2 versions
auto_cleanup_versions: true  # Auto-remove old versions
```

---

## Storage Configuration

### Directory Structure

```
/config/clawdbot/
├── cache/              # Built versions (in snapshots)
│   ├── v2026.1.24/
│   └── v2026.1.23/
├── data/               # User data (persistent)
│   ├── clawdbot.json   # Main config
│   ├── state/          # Runtime state
│   └── workspace/      # Skills & files
├── .meta/              # Version tracking
│   ├── current_version
│   ├── snapshot_version
│   └── last_run_version
└── source/             # Temporary source code
```

### Disk Usage

**Typical Usage:**
- Base install: ~500MB
- Per cached version: ~200MB
- Workspace (varies): 10-500MB
- Total (2 versions): ~1.5GB

**Recommendations:**
- Minimum free space: **2GB**
- Comfortable: **5GB**
- With extensive workspace: **10GB+**

---

## Messaging Integrations

### Telegram Setup (Detailed)

1. **Create Bot:**
   - Message [@BotFather](https://t.me/BotFather)
   - Send `/newbot`
   - Follow prompts
   - Copy the token

2. **Get Your User ID:**
   - Message [@userinfobot](https://t.me/userinfobot)
   - Copy your user ID

3. **Configure:**
   ```json
   {
     "telegram": {
       "enabled": true,
       "bot_token": "123456789:ABCdef...",
       "allowed_users": [123456789]
     }
   }
   ```

4. **Test:**
   - Start chat with your bot
   - Send `/start`
   - Try: "Hello, Claude!"

### WhatsApp Setup (Detailed)

1. **Enable in Config:**
   ```json
   {
     "whatsapp": {
       "enabled": true,
       "phone_number": "+1234567890"
     }
   }
   ```

2. **Pair Device:**
   - Restart add-on
   - Check logs for QR code
   - Scan with WhatsApp app
   - Wait for "Connected" message

3. **Test:**
   - Send message to the paired number
   - Should receive response

---

## Home Assistant Integration

### Ingress (Web UI)

Configured automatically:
```json
{
  "ingress": true,
  "ingress_port": 0,
  "ingress_entry": "/"
}
```

**Access:**
- Add-ons → Clawdbot Gateway → **OPEN WEB UI**
- OR: Sidebar → Clawdbot icon

### Sidebar Panel

```json
{
  "panel_icon": "mdi:robot",
  "panel_title": "Clawdbot",
  "panel_admin": false
}
```

**Customization:**
- Change `panel_icon` to any [Material Design Icon](https://materialdesignicons.com/)
- Set `panel_admin: true` to restrict to admins only

### Notifications

Update notifications are sent automatically:
- Update available (notify mode)
- Update succeeded
- Update failed
- Snapshot restore detected

**View in:**
- Home Assistant → Notifications bell icon

---

## Backup & Snapshot Configuration

### Included in Snapshots

```json
{
  "backup": "hot",
  "backup_exclude": [
    "source/clawdbot-src/.git",
    "source/clawdbot-src/node_modules",
    ".npm",
    ".cache"
  ]
}
```

**What's included:**
- ✅ User data (`/config/clawdbot/data/`)
- ✅ Cached versions (`/config/clawdbot/cache/`)
- ✅ Version metadata (`/config/clawdbot/.meta/`)
- ❌ Git repository (excluded, saves space)
- ❌ Temporary files (excluded)

**Benefits:**
- Instant restore (uses cached version)
- No rebuild required (~2 min vs 10+ min)
- Exact state preservation

---

## Performance Tuning

### Build Performance

```yaml
# Faster builds (uses cache)
max_cached_versions: 3
auto_cleanup_versions: true
```

### Memory Optimization

For low-memory systems (e.g., Raspberry Pi):
```json
{
  "model": "claude-haiku-4.0",
  "max_tokens": 4096
}
```

---

## Security Best Practices

1. **SSH (optional, Key-based):**
   - Setze `ssh_authorized_keys` nur wenn du SSH wirklich brauchst
   - PasswordAuthentication ist deaktiviert (keine Passwörter)

2. **API Keys:**
   - Store in `clawdbot.json` (not in add-on config)
   - Never commit to Git
   - Rotate periodically

3. **Telegram:**
   - Always use `allowed_users` whitelist
   - Don't share bot token publicly

4. **Network:**
   - Use Ingress instead of direct port access
   - Consider firewall rules if exposing port 18789

---

## Troubleshooting Configuration

### Check Current Configuration

```bash
# Add-on config
ha addons info local_clawdbot

# Clawdbot config
ssh -p 2222 root@YOUR-HA-IP
cat /config/clawdbot/data/clawdbot.json

# Current version
cat /config/clawdbot/.meta/current_version

# Cached versions
ls -lh /config/clawdbot/cache/
```

**Hinweis:** Die SSH-Kommandos funktionieren nur, wenn SSH in der Add-on Konfiguration via `ssh_authorized_keys` aktiviert wurde.

### Reset to Defaults

```bash
ssh -p 2222 root@YOUR-HA-IP
cd /config/clawdbot/data
mv clawdbot.json clawdbot.json.backup
# Restart add-on to regenerate defaults
```

### Configuration Validation

Logs will show errors:
```bash
ha addons logs local_clawdbot | grep -i error
```

Common issues:
- Invalid JSON syntax
- Missing required fields
- Incorrect API key format

---

## Example Configurations

### Minimal (Production)

```yaml
# Add-on config
update_mode: stable
max_cached_versions: 2
auto_cleanup_versions: true
```

```json
// clawdbot.json
{
  "anthropic_api_key": "sk-ant-api03-...",
  "model": "claude-sonnet-4.5"
}
```

### Full-Featured

```yaml
# Add-on config
ssh_port: 2222
ssh_authorized_keys: "ssh-ed25519 AAAA... user@host"  # Optional
update_mode: stable
max_cached_versions: 3
auto_cleanup_versions: true
```

```json
// clawdbot.json
{
  "anthropic_api_key": "sk-ant-api03-...",
  "model": "claude-sonnet-4.5",
  "max_tokens": 8192,
  "telegram": {
    "enabled": true,
    "bot_token": "123456789:ABC...",
    "allowed_users": [123456789]
  },
  "skills": {
    "enabled": true,
    "auto_update": true
  }
}
```

### Testing/Development

```yaml
# Add-on config
update_mode: latest
max_cached_versions: 5
pinned_version: ""
ssh_port: 2222
ssh_authorized_keys: "ssh-ed25519 AAAA... user@host"  # Optional
```

---

## Support

For configuration issues, see:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- [INSTALLATION.md](INSTALLATION.md)
- [GitHub Issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)

---

**Configuration complete! Your Clawdbot add-on is ready to use.**
