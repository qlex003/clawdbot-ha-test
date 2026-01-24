# Clawdbot HA Add-on - Troubleshooting Guide

Solutions to common problems and issues with the Clawdbot Home Assistant Add-on.

---

## Quick Diagnostics

Before diving into specific issues, run these diagnostic commands:

```bash
# Check add-on status
ha addons info local_clawdbot

# View recent logs
ha addons logs local_clawdbot

# Optional: SSH into container (nur wenn `ssh_authorized_keys` gesetzt ist)
ssh -p 2222 root@YOUR-HA-IP

# Check file structure
ls -la /config/clawdbot/

# Check current version
cat /config/clawdbot/.meta/current_version

# Check cached versions
ls /config/clawdbot/cache/
```

---

## Installation Issues

### Issue: Add-on Build Fails

**Symptoms:**
- Installation stuck at "Building..."
- Error: "Build failed"
- Logs show compilation errors

**Solutions:**

1. **Check disk space:**
   ```bash
   df -h /config
   ```
   - Need at least **2GB free**

2. **Check architecture support:**
   ```bash
   ha info | grep arch
   ```
   - Supported: `amd64`, `arm64`, `armv7`

3. **Check Docker logs:**
   ```bash
   ha addons logs local_clawdbot
   ```
   - Look for specific error messages

4. **Retry installation:**
   - Uninstall add-on
   - Reboot Home Assistant
   - Reinstall add-on

**Still failing?** Report issue with logs: [GitHub Issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)

---

### Issue: "tsc: not found" Error

**Symptoms:**
- Build fails with TypeScript error
- Error: `tsc: command not found`

**Solution:**
This was fixed in v1.0.0. Ensure you're using the latest version:

```yaml
# In repository.json, verify URL:
https://github.com/Al3xand3r1987/clawdbot-ha
```

If still occurring:
1. Remove add-on
2. Remove repository
3. Re-add repository (correct URL)
4. Reinstall add-on

---

### Issue: First Start Takes Too Long

**Symptoms:**
- Add-on starts but takes 15+ minutes
- Logs show "Installing dependencies..."

**Expected Behavior:**
- First start: **10-15 minutes** (building from source)
- Subsequent starts: **2-3 minutes** (using cache)

**If taking longer:**
1. Check system load: `ha host info`
2. Check network speed (downloading dependencies)
3. Be patient - Raspberry Pi can take 20+ minutes

**Pro Tip:** Watch logs to see progress:
```bash
ha addons logs local_clawdbot --follow
```

---

## Startup Issues

### Issue: Add-on Won't Start

**Symptoms:**
- Add-on shows "Stopped"
- Start button does nothing
- Logs show error immediately

**Solutions:**

1. **Check configuration syntax:**
   - Go to Configuration tab
   - Look for YAML errors (red highlights)

2. **Check logs for specific error:**
   ```bash
   ha addons logs local_clawdbot
   ```

3. **Common config errors:**
   - Missing quotes around strings
   - Invalid update_mode value
   - Invalid port number

4. **Reset to defaults:**
   - Remove all custom configuration
   - Try starting with minimal config:
     ```yaml
     update_mode: stable
     # Optional: SSH nur für Debug aktivieren (Key-based)
     ssh_port: 2222
     ssh_authorized_keys: "ssh-ed25519 AAAA... user@host"
     ```

---

### Issue: Add-on Starts Then Crashes

**Symptoms:**
- Starts successfully
- Runs for a few seconds
- Crashes with "Watchdog" or exits

**Solutions:**

1. **Check version compatibility:**
   ```bash
   cat /config/clawdbot/.meta/current_version
   ```

2. **Try pinning to stable version:**
   ```yaml
   update_mode: disabled
   pinned_version: "v2026.1.24"
   ```

3. **Check for corrupt cache:**
   ```bash
   ssh -p 2222 root@YOUR-HA-IP
   rm -rf /config/clawdbot/cache/*
   # Restart add-on
   ```

4. **Check smoke test logs:**
   ```bash
   ha addons logs local_clawdbot | grep "smoke test"
   ```

---

## SSH Connection Issues

### Issue: Cannot Connect via SSH

**Symptoms:**
- `ssh: connect to host X port 2222: Connection refused`
- `Permission denied (publickey)`

**Solutions:**

1. **Verify SSH is enabled (Key-based):**
   ```yaml
   ssh_port: 2222
   ssh_authorized_keys: "ssh-ed25519 AAAA... user@host"
   ```

2. **Check add-on is running:**
   ```bash
   ha addons info local_clawdbot | grep state
   ```

3. **Check SSH port is correct:**
   - Default: `2222`
   - Verify in add-on configuration

4. **Try with verbose SSH:**
   ```bash
   ssh -v -p 2222 root@YOUR-HA-IP
   ```

5. **Check firewall:**
   - Ensure port 2222 is not blocked
   - Try from same network first

6. **Update SSH key:**
   - Ersetze/ergänze `ssh_authorized_keys` in der Add-on Konfiguration
   - Restart add-on

---

### Issue: SSH Connects But No Shell

**Symptoms:**
- SSH connects successfully
- Immediately disconnects
- No shell prompt

**Solutions:**

1. **Check container health:**
   ```bash
   ha addons info local_clawdbot
   ```

2. **Try restarting add-on:**
   ```bash
   ha addons restart local_clawdbot
   ```

3. **Check logs for errors:**
   ```bash
   ha addons logs local_clawdbot
   ```

---

## Update Issues

### Issue: Update Fails

**Symptoms:**
- Logs show "update failed"
- Stays on old version
- Error during download/build

**Solutions:**

1. **Check update mode:**
   ```bash
   ha addons info local_clawdbot | grep update_mode
   ```

2. **Check disk space:**
   ```bash
   df -h /config
   ```
   - Updates need ~500MB free

3. **Check network connectivity:**
   ```bash
   ssh -p 2222 root@YOUR-HA-IP
   ping github.com
   ```

4. **Force manual update:**
   ```yaml
   update_mode: disabled
   pinned_version: "v2026.1.25"  # Latest stable
   ```
   - Restart add-on
   - Check logs for download progress

5. **Clear source repository:**
   ```bash
   ssh -p 2222 root@YOUR-HA-IP
   rm -rf /config/clawdbot/source/clawdbot-src
   # Restart add-on (will re-clone)
   ```

---

### Issue: Update Notification Not Appearing

**Symptoms:**
- `update_mode: notify`
- New version available
- No notification in HA

**Solutions:**

1. **Check HA notifications:**
   - Home Assistant → Notifications (bell icon)
   - Look for "Clawdbot" notifications

2. **Check logs:**
   ```bash
   ha addons logs local_clawdbot | grep "notification"
   ```

3. **Verify HA API access:**
   ```yaml
   hassio_api: true
   homeassistant_api: true
   ```

4. **Manual check:**
   ```bash
   ssh -p 2222 root@YOUR-HA-IP
   cd /config/clawdbot/source/clawdbot-src
   git fetch --tags
   git tag -l --sort=-version:refname | head -5
   ```

---

### Issue: Auto-Rollback Not Working

**Symptoms:**
- New version crashes
- Doesn't rollback to previous
- Stuck on broken version

**Solutions:**

1. **Check cached versions exist:**
   ```bash
   ls /config/clawdbot/cache/
   ```

2. **Manual rollback:**
   ```yaml
   update_mode: disabled
   pinned_version: "v2026.1.23"  # Previous version
   ```

3. **Check rollback logs:**
   ```bash
   ha addons logs local_clawdbot | grep -i "rollback\|crash"
   ```

4. **Force rebuild:**
   ```bash
   ssh -p 2222 root@YOUR-HA-IP
   rm -rf /config/clawdbot/cache/*
   rm /config/clawdbot/.meta/current_version
   ```
   - Set `pinned_version` to known-good version
   - Restart add-on

---

## Snapshot/Backup Issues

### Issue: Snapshot Restore Takes Too Long

**Symptoms:**
- Restore takes 15+ minutes
- Rebuilding from source

**Expected Behavior:**
- With cache: **~2 minutes**
- Without cache: **~10-15 minutes**

**Solutions:**

1. **Check if cache was in snapshot:**
   ```bash
   ls /config/clawdbot/cache/
   ```
   - Should see version directories

2. **Check restore detection:**
   ```bash
   ha addons logs local_clawdbot | grep "snapshot restore"
   ```
   - Should see "snapshot restore detected"

3. **If cache missing:**
   - Normal behavior if old snapshot (pre-v1.0)
   - Future snapshots will include cache

---

### Issue: Config Lost After Restore

**Symptoms:**
- Snapshot restored
- Clawdbot config missing
- Need to reconfigure API keys

**Solutions:**

1. **Check data directory:**
   ```bash
   ls -la /config/clawdbot/data/
   cat /config/clawdbot/data/clawdbot.json
   ```

2. **Check migration:**
   ```bash
   ha addons logs local_clawdbot | grep "migration"
   ```

3. **Manual restore from backup:**
   - If you have manual backups of `clawdbot.json`
   - Copy to `/config/clawdbot/data/clawdbot.json`
   - Restart add-on

4. **Prevention:**
   - Create snapshots regularly
   - Keep manual backup of `clawdbot.json`

---

### Issue: Version Mismatch After Restore

**Symptoms:**
- Restored snapshot
- Different version than expected
- Updates applied after restore

**Solutions:**

1. **This is by design** - Snapshot restore should preserve version
2. **Check snapshot version:**
   ```bash
   cat /config/clawdbot/.meta/snapshot_version
   ```

3. **If unwanted update occurred:**
   - Set `update_mode: disabled` before restore
   - Or pin to snapshot version after restore

---

## API & Integration Issues

### Issue: Anthropic API Key Not Working

**Symptoms:**
- "Invalid API key" error
- "Authentication failed"
- 401 Unauthorized

**Solutions:**

1. **Verify API key format:**
   - Should start with `sk-ant-api03-`
   - Check for extra spaces or line breaks

2. **Check where key is configured:**
   - Clawdbot config: `anthropic_api_key` in `/config/clawdbot/data/clawdbot.json` (oder über die Web UI)
   - Prefer Clawdbot config for security

3. **Test API key:**
   ```bash
   curl -H "x-api-key: YOUR-KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        https://api.anthropic.com/v1/messages \
        -d '{"model":"claude-sonnet-4.5","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
   ```

4. **Check API key validity:**
   - Visit [console.anthropic.com](https://console.anthropic.com)
   - Verify key is active
   - Check usage limits

5. **Regenerate API key:**
   - Create new key
   - Update configuration
   - Restart add-on

---

### Issue: Web UI Not Loading

**Symptoms:**
- "OPEN WEB UI" button shows error
- Blank page
- Connection refused

**Solutions:**

1. **Check add-on is running:**
   ```bash
   ha addons info local_clawdbot
   ```

2. **Check Ingress configuration:**
   ```bash
   ha addons info local_clawdbot | grep ingress
   ```
   - Should show `ingress: true`
   - Optional: if `easy_setup_ui: true`, try opening `/__setup/` inside the Ingress UI (setup proxy page)

3. **Try direct port access:**
   ```
   http://YOUR-HA-IP:18789
   ```
   **Note:** Ingress uses an internal proxy. Direct access only works if your Gateway bind/auth allows it.

4. **Check Gateway logs:**
   ```bash
   ha addons logs local_clawdbot | grep "started on port"
   ```
   - Should see "Gateway started on port 18789"

5. **Restart add-on:**
   ```bash
   ha addons restart local_clawdbot
   ```

6. **Clear browser cache:**
   - Ctrl+Shift+R (hard refresh)
   - Or incognito/private mode

---

### Issue: Telegram Bot Not Responding

**Symptoms:**
- Bot doesn't reply
- "Chat not found"
- Messages not received

**Solutions:**

1. **Verify bot token:**
   ```json
   {
     "telegram": {
       "enabled": true,
       "bot_token": "123456789:ABC..."
     }
   }
   ```

2. **Check user ID in whitelist:**
   ```json
   {
     "telegram": {
       "allowed_users": [123456789]
     }
   }
   ```
   - Get your ID from [@userinfobot](https://t.me/userinfobot)

3. **Start chat with bot:**
   - Send `/start` to your bot
   - Then try regular message

4. **Check bot logs:**
   ```bash
   ha addons logs local_clawdbot | grep -i telegram
   ```

5. **Test bot token:**
   ```bash
   curl https://api.telegram.org/bot<YOUR-TOKEN>/getMe
   ```

---

## Performance Issues

### Issue: Slow Responses

**Symptoms:**
- Web UI slow to load
- Commands take long time
- Gateway unresponsive

**Solutions:**

1. **Check system resources:**
   ```bash
   ha host info
   ```
   - CPU usage
   - Memory available

2. **Check model configuration:**
   ```json
   {
     "model": "claude-haiku-4.0"  // Faster than Sonnet/Opus
   }
   ```

3. **Reduce token limit:**
   ```json
   {
     "max_tokens": 4096  // Lower = faster
   }
   ```

4. **Check network latency:**
   ```bash
   ping api.anthropic.com
   ```

5. **Restart add-on:**
   ```bash
   ha addons restart local_clawdbot
   ```

---

### Issue: High Disk Usage

**Symptoms:**
- `/config` partition full
- "No space left on device"

**Solutions:**

1. **Check disk usage:**
   ```bash
   du -sh /config/clawdbot/*
   ```

2. **Reduce cached versions:**
   ```yaml
   max_cached_versions: 2  # Keep fewer versions
   auto_cleanup_versions: true
   ```

3. **Manual cleanup:**
   ```bash
   ssh -p 2222 root@YOUR-HA-IP

   # Remove old cached versions (keep current!)
   cd /config/clawdbot/cache
   ls -lt  # List by date
   rm -rf <old-version>/  # Remove old ones

   # Clean workspace if large
   du -sh /config/clawdbot/data/workspace/*
   ```

4. **Clean Docker cache:**
   ```bash
   ha host reboot
   ```

---

## Logging & Debugging

### Enable Debug Logging

```yaml
verbose: true
log_format: raw
```

Restart add-on and check logs:
```bash
ha addons logs local_clawdbot --follow
```

### View Specific Logs

```bash
# Update-related
ha addons logs local_clawdbot | grep -i update

# Version-related
ha addons logs local_clawdbot | grep -i version

# Error messages
ha addons logs local_clawdbot | grep -i error

# Snapshot/restore
ha addons logs local_clawdbot | grep -i snapshot

# Gateway startup
ha addons logs local_clawdbot | grep "started on port"
```

### Save Logs for Support

```bash
ha addons logs local_clawdbot > clawdbot-logs.txt
```

Attach to GitHub issue.

---

## Recovery Procedures

### Complete Reset (Nuclear Option)

**Warning:** This deletes ALL data (config, workspace, skills)

```bash
ssh -p 2222 root@YOUR-HA-IP
rm -rf /config/clawdbot
exit

# Restart add-on
ha addons restart local_clawdbot
```

Add-on will rebuild from scratch (~15 min).

---

### Preserve Data, Reset System

**Keeps:** Configuration, workspace, skills
**Resets:** Cached versions, source code

```bash
ssh -p 2222 root@YOUR-HA-IP

# Backup data
cp -r /config/clawdbot/data /config/clawdbot-backup

# Remove cache and source
rm -rf /config/clawdbot/cache
rm -rf /config/clawdbot/source
rm -rf /config/clawdbot/.meta

exit

# Restart add-on
ha addons restart local_clawdbot
```

---

### Rollback to Previous Version

```yaml
update_mode: disabled
pinned_version: "v2026.1.23"  # Replace with previous version
```

Restart add-on.

Check `/config/clawdbot/cache/` for available versions.

---

## Common Error Messages

### "Git clone failed"

**Cause:** Network issue or repository unavailable

**Solution:**
1. Check internet connection
2. Check GitHub status: [githubstatus.com](https://www.githubstatus.com/)
3. Wait and retry
4. Check DNS: `ping github.com`

---

### "Failed to build version"

**Cause:** Build error during update

**Solution:**
- Check logs for specific error
- System will rollback to previous version
- Report issue if persistent

---

### "Smoke test failed"

**Cause:** New version failed startup test

**Solution:**
- Automatic rollback to previous version
- Check release notes for known issues
- Pin to known-good version

---

### "Snapshot restore detected, but no cached version"

**Cause:** Restoring old snapshot (pre-v1.0) without cache

**Solution:**
- Normal behavior
- Wait for rebuild (~10-15 min)
- Future snapshots will include cache

---

## Still Having Issues?

### Before Requesting Support:

1. **Gather information:**
   ```bash
   ha addons info local_clawdbot > addon-info.txt
   ha addons logs local_clawdbot > addon-logs.txt
   ha host info > host-info.txt
   ```

2. **Check documentation:**
   - [INSTALLATION.md](INSTALLATION.md)
   - [CONFIGURATION.md](CONFIGURATION.md)
   - [README.md](README.md)

3. **Search existing issues:**
   - [GitHub Issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)

### Request Support:

- **GitHub Issues:** [Create Issue](https://github.com/Al3xand3r1987/clawdbot-ha/issues/new)
- **Include:**
  - Home Assistant version
  - Add-on version
  - Architecture (amd64/arm64/armv7)
  - Logs (relevant portions)
  - Steps to reproduce

---

**Most issues can be resolved with the solutions above. Good luck! 🚀**
