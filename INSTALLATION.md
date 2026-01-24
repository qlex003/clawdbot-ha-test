# Clawdbot HA Add-on - Installation Guide

Complete step-by-step installation guide for the Clawdbot Home Assistant Add-on.

---

## Prerequisites

Before installing the Clawdbot add-on, ensure you have:

- **Home Assistant OS** or **Home Assistant Supervised** installation
- **At least 2GB free disk space** (for builds and caching)
- **Optional:** SSH access (nur wenn du Debug/CLI im Container brauchst)
- **Anthropic API Key** (get one from [console.anthropic.com](https://console.anthropic.com))

### Supported Architectures

- `amd64` (Intel/AMD 64-bit)
- `arm64` (ARM 64-bit, e.g., Raspberry Pi 4/5)
- `armv7` (ARM 32-bit, e.g., Raspberry Pi 3)

---

## Installation Steps

### Step 1: Add Repository to Home Assistant

1. Open your **Home Assistant UI**
2. Navigate to **Settings → Add-ons → Add-on Store**
3. Click the **⋮** (three dots) in the top right corner
4. Select **Repositories**
5. Add this repository URL:
   ```
   https://github.com/Al3xand3r1987/clawdbot-ha
   ```
6. Click **Add**

The repository should now appear in your add-on store.

---

### Step 2: Install the Clawdbot Gateway Add-on

1. In the **Add-on Store**, scroll down to find **"Clawdbot Gateway"**
2. Click on the add-on
3. Click **Install**
4. Wait for the installation to complete (5-10 minutes)
   - The initial build includes:
     - Node.js, Bun, pnpm, TypeScript
     - GitHub CLI, gog CLI
     - Clawdbot source code and dependencies

---

### Step 3: Configure the Add-on

#### Basic Configuration

1. After installation, go to the **Configuration** tab
2. Set the following required options:

```yaml
update_mode: stable
```

**Key Options:**
- `update_mode`: How to handle updates (see [CONFIGURATION.md](CONFIGURATION.md))

#### Optional Configuration

```yaml
easy_setup_ui: false  # Optional: Setup-Seite im Ingress unter /__setup/ (OAuth/API Keys ohne SSH)
pinned_version: ""  # Optional: Pin to specific version
max_cached_versions: 2  # Keep 2 versions cached
auto_cleanup_versions: true  # Auto-cleanup old versions
ssh_port: 2222  # Optional: SSH Port (nur relevant wenn SSH aktiv)
ssh_authorized_keys: "ssh-ed25519 AAAA... user@host"  # Optional: SSH aktivieren (Key-based)
```

For a complete list of options, see [CONFIGURATION.md](CONFIGURATION.md).

---

### Step 4: Start the Add-on

1. Go to the **Info** tab
2. Enable **Start on boot** (recommended)
3. Enable **Watchdog** (optional, for auto-restart)
4. Click **Start**

**First Start Process:**
- Clones the Clawdbot repository
- Installs all dependencies
- Builds the Gateway and UI
- May take **10-15 minutes** on first start

**Monitor the logs:**
- Go to the **Log** tab
- Watch for `[INFO] Clawdbot Gateway started on port 18789`

---

### Step 5: Access Clawdbot

There are three ways to access Clawdbot:

#### Option A: Web UI (Ingress) - Recommended

1. Go to the **Info** tab of the add-on
2. Click the **"OPEN WEB UI"** button
3. The Clawdbot interface opens within Home Assistant

**Optional Setup (ohne SSH):** Wenn du `easy_setup_ui: true` setzt, kannst du im Ingress zusätzlich `/__setup/` öffnen (OAuth/API Keys).

**OR**

1. Check your **Home Assistant Sidebar**
2. Look for the **Clawdbot icon** (robot icon)
3. Click to open the interface

#### Option B: Direct Port Access

Access Clawdbot directly via:
```
http://YOUR-HA-IP:18789
```

#### Option C: SSH Configuration

For command-line configuration:

```bash
# From your computer
ssh -p 2222 root@YOUR-HA-IP

# Inside the container
cd /config/clawdbot/data
nano clawdbot.json
```

**Hinweis:** SSH ist optional und läuft nur, wenn `ssh_authorized_keys` in der Add-on Konfiguration gesetzt ist.

---

### Step 6: Configure Anthropic API Key

#### Via Setup UI (Ingress, ohne SSH) - Recommended

1. Set `easy_setup_ui: true` in the add-on Configuration (optional, but recommended for first setup)
2. Open the add-on Web UI (Ingress)
3. Open `/__setup/`
4. Paste your **Anthropic API Key** and click **Save**

#### Via Web UI (Easiest)

1. Open the Clawdbot Web UI (see Step 5)
2. Navigate to **Settings**
3. Enter your **Anthropic API Key**
4. Click **Save**

#### Via SSH

```bash
ssh -p 2222 root@YOUR-HA-IP

# Edit configuration
cd /config/clawdbot/data
nano clawdbot.json
```

Add your API key:
```json
{
  "anthropic_api_key": "sk-ant-api03-your-key-here",
  ...
}
```

Save and restart the add-on.

---

### Step 7: Verify Installation

1. **Check the logs:**
   ```
   ha addons logs local_clawdbot
   ```

   Look for:
   - `[INFO] Clawdbot Gateway started on port 18789`
   - `[INFO] using version: v2026.1.24` (or similar)
   - `[INFO] Server running at http://localhost:18789`

2. **Test the Web UI:**
   - Click "OPEN WEB UI"
   - You should see the Clawdbot interface
   - Try a simple command: "Hello, Claude!"

3. **Check file structure:**
   ```bash
   ssh -p 2222 root@YOUR-HA-IP
   ls -la /config/clawdbot/
   ```

   You should see:
   ```
   drwxr-xr-x cache/
   drwxr-xr-x data/
   drwxr-xr-x .meta/
   drwxr-xr-x source/
   ```

---

## First Time Setup Checklist

After installation, complete these steps:

- [ ] Add-on installed and started successfully
- [ ] Web UI accessible via "OPEN WEB UI" button
- [ ] Anthropic API key configured
- [ ] Test message sent and received
- [ ] (Optional) SSH access working (nur wenn aktiviert)
- [ ] Snapshot/Backup created (recommended)

---

## Update Strategy

The add-on includes an **automatic update system** with the following modes:

- **`stable` (default)**: Auto-updates to stable releases only
- **`notify`**: Notifies you when updates are available (manual approval)
- **`latest`**: Includes pre-releases (alpha, beta, rc)
- **`disabled`**: No automatic updates

Configure in the add-on **Configuration** tab via `update_mode`.

For more details, see [CONFIGURATION.md](CONFIGURATION.md#update-modes).

---

## Next Steps

After successful installation:

1. **Configure Telegram/WhatsApp** (optional)
   - See [CONFIGURATION.md](CONFIGURATION.md#messaging-integrations)

2. **Create your first snapshot**
   - Settings → System → Backups → Create Backup
   - Ensures you can restore if needed

3. **Explore Skills**
   - Use the Web UI to discover available skills
   - Skills are stored in `/config/clawdbot/data/workspace/`

4. **Join the Community**
   - Report issues: [GitHub Issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)
   - Contribute: See [CLAUDE.md](CLAUDE.md)

---

## Migration from v0.2.14

If you're upgrading from an earlier version (v0.2.14), the add-on will **automatically migrate** your data on first start:

- Old location: `/config/clawdbot/.clawdbot/`
- New location: `/config/clawdbot/data/`

**Your data is preserved:**
- `clawdbot.json` configuration
- State data
- Workspace and skills

No manual steps required!

---

## Troubleshooting

If you encounter issues during installation, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for:

- Build failures
- SSH connection issues
- API key problems
- Update failures
- Snapshot restore issues

---

## Support

Need help?

- **Documentation**: [README.md](README.md), [CONFIGURATION.md](CONFIGURATION.md)
- **Issues**: [GitHub Issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)
- **Community**: Home Assistant Community Forums

---

**Installation complete! Enjoy using Clawdbot with Home Assistant! 🎉**
