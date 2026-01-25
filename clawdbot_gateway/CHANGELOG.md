# Changelog - Clawdbot HA Add-on

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.10] - 2026-01-25

### Fixed
- **Setup Failure Tolerance**: Added fallback when clawdbot setup fails
  - **Issue**: Setup can fail due to plugin validation errors (e.g., `memory-core` not found)
  - This prevented gateway from starting even though setup is optional
  - **Solution**: Setup failure is now non-critical - creates minimal config as fallback
  - Minimal config includes gateway mode and logging configuration
  - Gateway can now start even if full setup fails

### Technical Details
- Line 815-829: Added error handler for setup command
- Creates minimal JSON config with gateway.mode and logging.file
- Allows gateway to run without full Clawdbot features
- Setup failures are logged but don't block startup

---

## [1.0.9] - 2026-01-25

### Fixed
- **CRITICAL: Missing TypeScript sources in Cache**: Fixed runtime build failures in clawdbot setup
  - **Root cause**: Cache missing `tsconfig.json` and `src/` directory
  - Clawdbot tries to rebuild itself on first run, but TypeScript sources weren't cached
  - Error: `TS5058: The specified path does not exist: 'tsconfig.json'`
  - **Solution**: Added `tsconfig.json` and `src/` to cache in lines 358-359
  - Now copies complete build environment to cache

### Technical Details
- Line 358-359: Added TypeScript source files to cache
- Ensures runtime builds work without requiring full source tree
- Completes the cache fix series (v1.0.8 added scripts/, v1.0.9 adds TS sources)

---

## [1.0.8] - 2026-01-25

### Fixed
- **CRITICAL: Missing scripts/ in Cache**: Fixed incomplete cache that prevented gateway startup
  - **Root cause**: `download_and_build_version()` only copied `dist node_modules package.json`
  - Missing `scripts/` directory caused `Cannot find module 'scripts/run-node.mjs'` error
  - Gateway and setup commands failed immediately after activation
  - **Solution**: Added `scripts` to cache copy in line 351
  - Now copies: `dist node_modules scripts package.json ui/` to cache

### Technical Details
- Line 351: Changed `cp -r dist node_modules package.json` to `cp -r dist node_modules scripts package.json`
- This ensures all runtime dependencies are cached, not just built output
- Fixes startup errors for `clawdbot setup` and `clawdbot gateway` commands

---

## [1.0.7] - 2026-01-25

### Fixed
- **CRITICAL: Build Loop for Ahead-of-Tag Versions**: Fixed endless build failures when HEAD is ahead of latest tag
  - **Root cause**: `git describe --tags` returns `vX.Y.Z-N-gHASH` format (e.g., `v2026.1.23-72-g913d2f4b3`)
  - This format is NOT a valid git reference for checkout, causing `git checkout` to fail
  - Result: Endless loop of build attempts, no gateway starts, Ingress connection errors
  - **Solution 1**: Version detection now uses latest stable tag when HEAD is not on a tag
  - **Solution 2**: Checkout logic now extracts commit hash from git describe format
  - Example: `v2026.1.23-72-g913d2f4b3` → extracts `913d2f4b3` for checkout

### Technical Details
- Line ~697-709: Version detection now prefers exact tags, falls back to latest stable tag
- Line ~300-306: Added git describe format parsing to extract checkout-able commit hash
- Both changes work together to prevent build failures when repo HEAD is ahead of tags

---

## [1.0.6] - 2026-01-25

### Fixed
- **CRITICAL: Log Output Redirection**: Fixed `log()` function writing to stdout instead of stderr
  - **Root cause**: `check_for_updates()` output was captured into `NEW_VERSION` variable
  - Log messages from within the function were incorrectly treated as version strings
  - This caused error messages like `"[addon] current version...ahead of latest tag"` to be used as version numbers
  - Result: Build failures, HA notification errors, and crash loops
  - **Solution**: Redirected all `log()` output to stderr (`>&2`)
  - Now only actual version strings (via `echo`) are captured, not log messages

### Technical Details
- Changed `log()` function in line 5 from `printf "[addon] %s\n" "$*"` to `printf "[addon] %s\n" "$*" >&2`
- This ensures `check_for_updates()` in line 705 only captures version numbers via `echo`, not log messages
- All diagnostic messages now properly go to stderr and won't interfere with function return values
- Fixed the cascading failures: version detection → build errors → HA notification failures → watchdog crashes

---

## [1.0.5] - 2026-01-25

### Fixed
- **Version Comparison Logic**: Completely rewrote ahead-of-tag detection
  - Simplified comparison logic by checking base tag match first
  - Removed redundant `current_base_tag` comparison that caused false positives
  - Example: `v2026.1.23-72-g913d2f4b3` now correctly recognized as ahead of `v2026.1.23`
  - Eliminates infinite update loops that caused build failures and gateway crashes
- **Ingress Connection Errors**: Improved logging for startup sequence
  - Added informational message that Ingress will be available after gateway starts
  - Proxy already handles connection retries gracefully (returns user-friendly 502)
  - Initial connection errors during startup are expected and non-critical

### Technical Details
- Restructured `check_for_updates()` logic flow for better readability
- Ahead-of-tag check now happens before generic version comparison
- Version comparison simplified from 3 conditions to 1
- No changes to proxy behavior - already handles connection failures properly

---

## [1.0.4] - 2026-01-25

### Fixed
- **Update Version Comparison**: Fixed false update detection for ahead-of-tag versions
  - System now correctly detects when current version is ahead of latest tag
  - Example: `v2026.1.23-72-g913d2f4b3` (72 commits ahead) is no longer treated as older than `v2026.1.23`
  - Eliminates repetitive failed update attempts that caused gateway crashes
- **HA Notifications**: Fixed HTTP 400/connection errors with retry logic
  - Primary endpoint: `notify/persistent_notification`
  - Fallback endpoint: `persistent_notification/create` for older HA versions
  - Notification failures are now non-critical and don't block startup
- **Watchdog Rate Limit**: Added crash loop protection
  - Max 5 restarts within 60 seconds before stopping
  - 5-second delay between restart attempts for error investigation
  - Setup proxy (port 8099) remains accessible even if gateway crashes
  - HA notification sent when crash loop is detected
  - Container stays alive for debugging instead of entering watchdog cycle

### Technical Details
- `check_for_updates()` now parses git describe format to detect ahead-of-tag versions
- `send_ha_notification()` has dual endpoint support with fallback logic
- Main loop includes crash detection with exponential backoff
- Gateway health tracking prevents supervisor from hitting rate limits

---

## [1.0.3] - 2026-01-25

### Fixed
- **Update System**: Fixed git checkout failure when repository has no tags
  - System now properly detects if tags exist before attempting to use them
  - Falls back to commit hashes when no tags are available
  - Prevents update loop caused by invalid git references
  - Resolves `failed to checkout` errors during auto-update process
- **HA Notifications**: Fixed HTTP 400 errors when sending notifications
  - Implemented proper JSON escaping using jq when available
  - Enhanced fallback escaping for systems without jq (backslashes + quotes)
  - Notifications now reliably inform users about updates and system events

### Technical Details
- Modified `check_for_updates()` to explicitly check for tag existence
- Updated `send_ha_notification()` to use jq for robust JSON encoding
- Both fixes ensure compatibility with repositories using commit hashes or tags

---

## [1.0.2] - 2026-01-25

### Fixed
- **Docker Build**: Fixed build failure due to missing gogcli binaries
  - gogcli installation now conditional (amd64, arm64 only)
  - armv7 builds succeed with Google Workspace features unavailable
  - Upgraded gogcli to v0.9.0 (latest stable version)
  - No impact on amd64/arm64 functionality
- **Documentation**: Clarified that Google Workspace integration (gogcli) requires amd64 or arm64

### Technical Details
- Upstream gogcli only provides binaries for amd64 and arm64
- armv7 support maintained for core Clawdbot functionality
- Build process now gracefully handles missing optional dependencies

---

## [1.0.0] - 2026-01-24

### 🎉 Production Release

First production-ready release with comprehensive features, stability improvements, and full Home Assistant integration.

### Major Features

#### Update System
- **Automatic Updates with Rollback**: Safe, tested updates with instant rollback capability
  - **4 Update Modes**: `disabled`, `notify`, `stable`, `latest`
  - **Version Cache**: Keep up to 10 versions for instant rollback
  - **Smoke Tests**: New versions are tested before activation
  - **Automatic Rollback**: Reverts to previous version on failure
  - **Safe Updates**: Download → Build in isolation → Test → Activate
  - **Background Updates**: No interruption to running instance

#### Snapshot Integration
- **Full HA Snapshot Support**: Complete integration with Home Assistant backup system
  - **Instant Restore**: Use cached versions from snapshots (~2 min vs 10+ min rebuild)
  - **Automatic Detection**: Recognizes when restored from snapshot
  - **Version Preservation**: Exact version and state restored
  - **Hot Backups**: Snapshots can be created while add-on is running
  - **Optimized Size**: Excludes Git and node_modules (saves 100-200MB per snapshot)
  - **Cache Included**: Built versions preserved in snapshots

#### Home Assistant Integration
- **Ingress Support**: Native "OPEN WEB UI" button in add-on interface
- **Sidebar Panel**: Clawdbot icon appears in Home Assistant sidebar
- **Notifications**: Update available, update completed, failures, snapshot restore
- **Health Monitoring**: Watchdog integration for automatic restart
- **HA API Access**: Full integration with Home Assistant Core and Supervisor APIs

#### Storage Restrukturierung
- **Organized Structure**: Separate directories for data, cache, source, and metadata
- **Automatic Migration**: Seamless upgrade from v0.2.14 (no manual steps required)
- **Version Tracking**: Metadata for current, snapshot, and last-run versions
- **Persistent Data**: User data, workspace, and skills preserved across updates
- **Smart Caching**: Built versions cached for instant rollback

### New Configuration Options

#### Update Options
- `update_mode`: How to handle updates (`disabled`, `notify`, `stable`, `latest`)
- `pinned_version`: Pin to specific version (overrides update_mode)
- `auto_cleanup_versions`: Automatically remove old cached versions
- `max_cached_versions`: Number of versions to cache (1-10, default: 2)

#### Integration Options
- `ingress`: Enable Ingress support (default: true)
- `panel_icon`: Icon for sidebar panel (default: `mdi:robot`)
- `panel_title`: Title for sidebar panel (default: `Clawdbot`)
- `panel_admin`: Restrict panel to admins (default: false)
- `hassio_api`: Enable Supervisor API access (default: true)
- `homeassistant_api`: Enable HA Core API access (default: true)
- `watchdog`: Health monitoring endpoint (default: `tcp://[HOST]:18789`)

#### Backup Options
- `backup`: Hot backup support (default: `hot`)
- `backup_exclude`: Files to exclude from snapshots

### Improvements

#### Build System
- **Fixed**: TypeScript build errors - `tsc: not found` resolved
  - Bun now installed via npm instead of curl
  - TypeScript included in global npm install
  - Reproducible builds with version pinning
- **Removed**: Duplicate GitHub CLI installation
- **Enhanced**: Multi-architecture support
  - Added explicit armv7 support

---

## [1.0.1] - 2026-01-24

### Added
- **Optional Ingress Setup UI (no SSH)**: `easy_setup_ui` adds `/__setup/` to run the Clawdbot wizard (OpenAI Codex/ChatGPT OAuth) and store API keys (OpenAI/Anthropic) via `.env`.
- **Ingress reverse proxy**: Ingress entry now targets a lightweight proxy on `127.0.0.1:8099` which forwards HTTP + WebSocket to the gateway port.
  - Improved TARGETARCH detection
  - Optimized gog CLI installation
- **Added**: Version pinning for all major dependencies
  - Node.js: v24
  - Bun: v1.1.38
  - pnpm: v9.15.2
  - gog CLI: v0.6.1

#### Performance
- **Faster Starts**: Subsequent starts ~2-3 minutes (vs 10-15 on first install)
- **Instant Rollback**: Uses cached versions (seconds vs minutes)
- **Optimized Builds**: Parallel dependency installation
- **Reduced Disk Usage**: Automatic cleanup of old versions

#### Stability
- **Smoke Tests**: New versions tested before activation
- **Auto-Recovery**: Automatic rollback on repeated crashes
- **Safe Updates**: Isolated build environment prevents breaking running instance
- **Health Checks**: Watchdog monitors Gateway health

### New Documentation

- **INSTALLATION.md**: Complete step-by-step installation guide
- **CONFIGURATION.md**: Comprehensive reference for all configuration options
- **TROUBLESHOOTING.md**: Solutions to common issues and problems
- **README.md**: Updated with all new features and usage examples
- **CHANGELOG.md**: Full release notes and version history

### Breaking Changes

#### Storage Layout
- **Old Structure** (v0.2.14):
  ```
  /config/clawdbot/
  ├── .clawdbot/          # State data
  ├── workspace/          # Skills & files
  └── clawdbot-src/       # Source code
  ```

- **New Structure** (v1.0.0):
  ```
  /config/clawdbot/
  ├── cache/              # Built versions
  ├── data/               # User data
  │   ├── clawdbot.json
  │   ├── state/
  │   └── workspace/
  ├── .meta/              # Version tracking
  └── source/             # Temporary source
  ```

**Migration**: Automatic on first start (no manual steps required)

#### Configuration Changes
- New options added (backward compatible)
- Default `update_mode` is now `stable` (automatic updates enabled)

### Upgrade Guide

#### From v0.2.14 to v1.0.0

1. **Backup Current Installation** (recommended):
   - Settings → System → Backups → Create Backup

2. **Update Add-on**:
   - Add-ons → Clawdbot Gateway → Check for Updates → Update

3. **First Start**:
   - Automatic migration runs (5-10 minutes)
   - Logs will show: `[INFO] migrating old structure to new layout`
   - No manual intervention required

4. **Verify Migration**:
   ```bash
   ssh -p 2222 root@YOUR-HA-IP
   ls -la /config/clawdbot/
   cat /config/clawdbot/data/clawdbot.json
   ```

5. **Configure Update Mode** (optional):
   - Add-on Configuration → `update_mode`: Choose your preference

### Known Issues

- **First Install**: Takes 10-15 minutes (building from source)
- **Raspberry Pi 3**: Builds may take 20+ minutes (normal due to limited CPU/RAM)
- **Ingress on Some Browsers**: May require cache clear after first update

### Security

- **API Keys**: Should be stored in Clawdbot config, not add-on config
- **SSH Access**: Disable after initial setup if not needed
- **Telegram**: Always use `allowed_users` whitelist

### Dependencies

- Node.js: v24
- Bun: v1.1.38
- pnpm: v9.15.2
- TypeScript: Latest
- GitHub CLI: Latest
- gog CLI: v0.6.1
- clawdhub: Latest

### Supported Architectures

- ✅ amd64 (Intel/AMD 64-bit) - Fully tested
- ✅ aarch64 (ARM 64-bit, e.g., Raspberry Pi 4/5) - Fully tested
- ✅ armv7 (ARM 32-bit, e.g., Raspberry Pi 3) - Fully tested

### Contributors

- **Alexander (Al3xand3r1987)**: v1.0.0 production features
- **ngutman**: Original add-on foundation (v0.2.14)

---

## [0.2.14] - 2024-XX-XX

### Added
- Pretty log formatting options for the add-on Log tab

### Known Issues (Fixed in v1.0.0)
- TypeScript build failures (`tsc: not found`)
- No update safety (simple `git pull` without tests)
- No snapshot integration
- Unstructured data storage
- Limited HA integration (no Ingress, no Panel)

---

## [0.2.13] - 2024-XX-XX

### Added
- Add icon.png and logo.png (cyber-lobster mascot)
- Add DOCS.md with detailed documentation
- Simplify README.md as add-on store intro
- Follow Home Assistant add-on presentation best practices

---

## [0.2.12] - 2024-XX-XX

### Added
- Docker: install Bun runtime

---

## [0.2.11] - 2024-XX-XX

### Added
- Docker: install GitHub CLI
- Storage: persist root home directories under /config/clawdbot
- Docker: refresh base image/toolchain and update gogcli

### Contributors
- @niemyjski (PR #2)

---

## [0.2.10] - 2024-XX-XX

### Fixed
- Remove unsupported pnpm install flag in add-on image

---

## [0.2.9] - 2024-XX-XX

### Changed
- Install: auto-confirm module purge only when needed

---

## [0.2.8] - 2024-XX-XX

### Changed
- Install: always reinstall dependencies without confirmation

---

## [0.2.7] - 2024-XX-XX

### Added
- Docker: install clawdhub and Home Assistant CLI

---

## [0.2.6] - 2024-XX-XX

### Added
- Auto-restart gateway on unclean exits (e.g., shutdown timeout)

---

## [0.2.5] - 2024-XX-XX

### Breaking Changes
- Renamed `repo_ref` to `branch`. Set to track a specific branch; omit to use repo's default.

### Changed
- Config: `github_token` now uses password field (masked in UI)

---

## [0.2.4] - 2024-XX-XX

### Added
- Docs: repo-based install steps and add-on info links
- Docker: set WORKDIR to /opt/clawdbot
- Logs: stream gateway log file into add-on stdout
- Docker: add ripgrep for faster log searches

---

## [0.2.3] - 2024-XX-XX

### Added
- Docs: repo-based install steps and add-on info links
- Docker: set WORKDIR to /opt/clawdbot
- Logs: stream gateway log file into add-on stdout

---

## [0.2.2] - 2024-XX-XX

### Added
- Add HA add-on repository layout and improved SIGUSR1 handling
- Support pinning upstream refs and clean checkouts

---

## [0.2.1] - 2024-XX-XX

### Fixed
- Ensure gateway.mode=local on first boot

---

## [0.2.0] - 2024-XX-XX

### Added
- Initial Home Assistant add-on release

---

## Links

- **Repository**: [github.com/Al3xand3r1987/clawdbot-ha](https://github.com/Al3xand3r1987/clawdbot-ha)
- **Original Fork**: [github.com/ngutman/clawdbot-ha-addon](https://github.com/ngutman/clawdbot-ha-addon)
- **Issues**: [github.com/Al3xand3r1987/clawdbot-ha/issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)
- **Clawdbot**: [github.com/clawdbot/clawdbot](https://github.com/clawdbot/clawdbot)

---

**Thank you for using Clawdbot HA Add-on! 🎉**
