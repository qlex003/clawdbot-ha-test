#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "[addon] %s\n" "$*"
}

log "run.sh version=2026-01-24-v1.0.0-ha-integration"

# ============================================================================
# PHASE 2: Neue Verzeichnisstruktur (v1.0.0)
# ============================================================================
# Ziel-Layout:
# /config/clawdbot/
# ├── cache/                    # Gebaute Versionen (IN SNAPSHOT!)
# │   ├── v2026.1.22/
# │   │   ├── dist/
# │   │   ├── node_modules/
# │   │   ├── ui/
# │   │   └── .version
# │   └── v2026.1.25/
# ├── data/                     # USER-DATEN (persistent)
# │   ├── clawdbot.json        # Haupt-Config
# │   ├── state/               # State-Daten
# │   └── workspace/           # Skills & Dateien
# ├── .meta/                    # Version-Tracking
# │   ├── current_version
# │   ├── snapshot_version
# │   └── last_run_version
# └── source/                   # Temporärer Source-Code
#     └── clawdbot-src/
# ============================================================================

BASE_DIR=/config/clawdbot

# Neue Verzeichnis-Definitionen (v1.0.0)
DATA_DIR="${BASE_DIR}/data"
CACHE_DIR="${BASE_DIR}/cache"
META_DIR="${BASE_DIR}/.meta"
SOURCE_DIR="${BASE_DIR}/source"
REPO_DIR="${SOURCE_DIR}/clawdbot-src"
WORKSPACE_DIR="${DATA_DIR}/workspace"
STATE_DIR="${DATA_DIR}/state"
CONFIG_PATH="${DATA_DIR}/clawdbot.json"
SSH_AUTH_DIR="${BASE_DIR}/.ssh"

# Legacy-Pfade für Migration
LEGACY_STATE_DIR="${BASE_DIR}/.clawdbot"
LEGACY_REPO_DIR="${BASE_DIR}/clawdbot-src"
LEGACY_WORKSPACE_DIR="${BASE_DIR}/workspace"

# Verzeichnisse erstellen
mkdir -p "${DATA_DIR}" "${CACHE_DIR}" "${META_DIR}" "${SOURCE_DIR}" \
         "${WORKSPACE_DIR}" "${STATE_DIR}" "${SSH_AUTH_DIR}"

# Create persistent directories
mkdir -p "${BASE_DIR}/.config/gh" "${BASE_DIR}/.local" "${BASE_DIR}/.cache" "${BASE_DIR}/.npm" "${BASE_DIR}/bin"

# ============================================================================
# Automatische Migration von alter Struktur (EINMALIG)
# ============================================================================
migrate_legacy_structure() {
  local migrated=false

  # 1. State-Daten migrieren (.clawdbot -> data/state)
  if [ -d "${LEGACY_STATE_DIR}" ] && [ ! -f "${CONFIG_PATH}" ]; then
    log "migrating old .clawdbot structure to new layout"

    # State-Daten kopieren (nicht verschieben, für Sicherheit)
    cp -a "${LEGACY_STATE_DIR}/." "${STATE_DIR}/" 2>/dev/null || true

    # Haupt-Config verschieben
    if [ -f "${STATE_DIR}/clawdbot.json" ]; then
      mv "${STATE_DIR}/clawdbot.json" "${CONFIG_PATH}"
      log "config migrated to ${CONFIG_PATH}"
    fi

    migrated=true
  fi

  # 2. Workspace verschieben falls vorhanden
  if [ -d "${LEGACY_WORKSPACE_DIR}" ] && [ ! -d "${WORKSPACE_DIR}" ]; then
    log "migrating workspace to new location"
    mv "${LEGACY_WORKSPACE_DIR}" "${WORKSPACE_DIR}"
    migrated=true
  elif [ -d "${LEGACY_WORKSPACE_DIR}" ] && [ -d "${WORKSPACE_DIR}" ]; then
    # Beide existieren - merge contents
    cp -rn "${LEGACY_WORKSPACE_DIR}/." "${WORKSPACE_DIR}/" 2>/dev/null || true
    log "workspace merged to new location"
  fi

  # 3. Source-Repo verschieben falls vorhanden
  if [ -d "${LEGACY_REPO_DIR}/.git" ] && [ ! -d "${REPO_DIR}/.git" ]; then
    log "migrating source repo to new location"
    mkdir -p "${SOURCE_DIR}"
    mv "${LEGACY_REPO_DIR}" "${REPO_DIR}"
    migrated=true
  fi

  if [ "${migrated}" = "true" ]; then
    log "migration complete"
  fi
}

# Migration ausführen
migrate_legacy_structure

# ============================================================================
# Symlinks für /root (für Tools die $HOME ignorieren)
# ============================================================================
for dir in .ssh .config .local .cache .npm; do
  target="${BASE_DIR}/${dir}"
  link="/root/${dir}"
  if [ -L "${link}" ]; then
    :
  elif [ -d "${link}" ]; then
    cp -rn "${link}/." "${target}/" 2>/dev/null || true
    rm -rf "${link}"
    ln -s "${target}" "${link}"
  else
    rm -f "${link}" 2>/dev/null || true
    ln -s "${target}" "${link}"
  fi
done
log "persistent home symlinks configured"

# Legacy: /root/.clawdbot migration
if [ -d /root/.clawdbot ] && [ ! -f "${CONFIG_PATH}" ]; then
  cp -a /root/.clawdbot/. "${STATE_DIR}/"
  if [ -f "${STATE_DIR}/clawdbot.json" ]; then
    mv "${STATE_DIR}/clawdbot.json" "${CONFIG_PATH}"
  fi
fi

# Legacy: /root/clawdbot-src migration
if [ -d /root/clawdbot-src ] && [ ! -d "${REPO_DIR}" ]; then
  mkdir -p "${SOURCE_DIR}"
  mv /root/clawdbot-src "${REPO_DIR}"
fi

# Legacy: /root/workspace migration
if [ -d /root/workspace ] && [ ! -d "${WORKSPACE_DIR}" ]; then
  mv /root/workspace "${WORKSPACE_DIR}"
fi

# ============================================================================
# Environment-Variablen (v1.0.0)
# ============================================================================
export HOME="${BASE_DIR}"
export CLAWDBOT_STATE_DIR="${STATE_DIR}"
export CLAWDBOT_CONFIG_PATH="${CONFIG_PATH}"
export CLAWDBOT_CACHE_DIR="${CACHE_DIR}"
export CLAWDBOT_META_DIR="${META_DIR}"

log "config path=${CONFIG_PATH}"
log "cache dir=${CACHE_DIR}"
log "meta dir=${META_DIR}"

cat > /etc/profile.d/clawdbot.sh <<EOF
export HOME="${BASE_DIR}"
export GH_CONFIG_DIR="${BASE_DIR}/.config/gh"
export PATH="${BASE_DIR}/bin:\${PATH}"
export CLAWDBOT_STATE_DIR="${STATE_DIR}"
export CLAWDBOT_CONFIG_PATH="${CONFIG_PATH}"
export CLAWDBOT_CACHE_DIR="${CACHE_DIR}"
export CLAWDBOT_META_DIR="${META_DIR}"
if [ -n "\${SSH_CONNECTION:-}" ]; then
  cd "${REPO_DIR}" 2>/dev/null || cd "${SOURCE_DIR}/active" 2>/dev/null || true
fi
EOF

# ============================================================================
# PHASE 3: Version-Tracking Funktionen (v1.0.0)
# ============================================================================

# Version-Tracking: Aktuelle Version ermitteln
get_current_version() {
  if [ -f "${META_DIR}/current_version" ]; then
    cat "${META_DIR}/current_version"
  else
    echo ""
  fi
}

# Version-Tracking: Aktuelle Version setzen
set_current_version() {
  local version="$1"
  echo "${version}" > "${META_DIR}/current_version"
  echo "${version}" > "${META_DIR}/last_run_version"
  log "version set to ${version}"
}

# Update-Check: Prüft ob neue Version verfügbar ist
check_for_updates() {
  local current_version="$1"
  local update_mode="$2"
  local pinned_version="$3"

  # Repo-Verzeichnis muss existieren
  [ ! -d "${REPO_DIR}/.git" ] && return 1

  cd "${REPO_DIR}" || return 1
  if [ -n "${GIT_HTTP_EXTRAHEADER:-}" ]; then
    git -c http.extraheader="${GIT_HTTP_EXTRAHEADER}" fetch --tags --prune 2>/dev/null || return 1
  else
    git fetch --tags --prune 2>/dev/null || return 1
  fi

  # Updates deaktiviert?
  [ "${update_mode}" = "disabled" ] && return 1

  # Gepinnte Version hat Priorität
  if [ -n "${pinned_version}" ] && [ "${pinned_version}" != "null" ]; then
    if [ "${pinned_version}" != "${current_version}" ]; then
      echo "${pinned_version}"
      return 0
    fi
    return 1
  fi

  # Neueste Version bestimmen
  local target_version=""
  if [ "${update_mode}" = "latest" ]; then
    # Inkl. Pre-Releases (alpha, beta, rc)
    target_version=$(git tag -l --sort=-version:refname | head -1)
  else
    # Nur stable (keine alpha/beta/rc)
    target_version=$(git tag -l --sort=-version:refname | grep -v -E '(alpha|beta|rc)' | head -1)
  fi

  # Fallback zu aktuellen commit
  [ -z "${target_version}" ] && target_version=$(git rev-parse --short HEAD)

  # Ist es eine neue Version?
  if [ "${target_version}" != "${current_version}" ]; then
    log "update available: ${current_version} → ${target_version}"
    echo "${target_version}"
    return 0
  fi

  return 1
}

# Isolierter Build: Version herunterladen und bauen
download_and_build_version() {
  local version="$1"
  local build_dir="${CACHE_DIR}/${version}"

  # Bereits gecacht?
  if [ -d "${build_dir}" ] && [ -f "${build_dir}/.version" ]; then
    log "version ${version} already cached"
    return 0
  fi

  log "downloading and building version ${version}"

  # Temporäres Build-Verzeichnis
  local temp_dir="/tmp/clawdbot-build-${version}-$$"
  rm -rf "${temp_dir}"
  mkdir -p "${temp_dir}"

  # Source-Code in temp kopieren
  cp -r "${REPO_DIR}" "${temp_dir}/clawdbot-src" || {
    log "failed to copy source"
    rm -rf "${temp_dir}"
    return 1
  }

  cd "${temp_dir}/clawdbot-src" || {
    rm -rf "${temp_dir}"
    return 1
  }

  # Zur gewünschten Version wechseln
  git fetch --all --tags >/dev/null 2>&1 || true
  git checkout "${version}" >/dev/null 2>&1 || {
    log "failed to checkout ${version}"
    rm -rf "${temp_dir}"
    return 1
  }

  # Dependencies installieren
  log "installing dependencies for ${version}"
  pnpm install --no-frozen-lockfile --prefer-frozen-lockfile >/dev/null 2>&1 || {
    log "failed to install dependencies"
    rm -rf "${temp_dir}"
    return 1
  }

  # Gateway bauen
  log "building gateway for ${version}"
  pnpm build >/dev/null 2>&1 || {
    log "build failed for ${version}"
    rm -rf "${temp_dir}"
    return 1
  }

  # UI bauen
  if [ -d "ui" ]; then
    log "building UI for ${version}"
    [ ! -d "ui/node_modules" ] && pnpm ui:install >/dev/null 2>&1
    pnpm ui:build >/dev/null 2>&1 || {
      log "UI build failed for ${version}"
      rm -rf "${temp_dir}"
      return 1
    }
  fi

  # Smoke-Test: Gateway starten und sofort beenden
  log "smoke testing ${version}"
  timeout 10 node dist/index.js --version >/dev/null 2>&1 || {
    log "smoke test failed for ${version}"
    rm -rf "${temp_dir}"
    return 1
  }

  # In Cache verschieben
  mkdir -p "${build_dir}"
  cp -r dist node_modules package.json "${build_dir}/" || {
    log "failed to cache build"
    rm -rf "${temp_dir}"
    return 1
  }

  # UI falls vorhanden
  [ -d "ui" ] && cp -r ui "${build_dir}/" || true

  # Version-Marker
  echo "${version}" > "${build_dir}/.version"

  # Cleanup
  rm -rf "${temp_dir}"
  log "version ${version} built and cached successfully"
  return 0
}

# Version aktivieren: Symlink zu gecachter Version erstellen
activate_version() {
  local version="$1"
  local cache_path="${CACHE_DIR}/${version}"

  # Gecachte Version existiert?
  if [ ! -d "${cache_path}" ] || [ ! -f "${cache_path}/.version" ]; then
    log "cached version ${version} not found"
    return 1
  fi

  local active_dir="${SOURCE_DIR}/active"

  # Alten Symlink/Verzeichnis entfernen
  rm -rf "${active_dir}"

  # Symlink erstellen (oder kopieren falls Symlinks nicht funktionieren)
  ln -s "${cache_path}" "${active_dir}" 2>/dev/null || {
    mkdir -p "${active_dir}"
    cp -r "${cache_path}/." "${active_dir}/"
  }

  set_current_version "${version}"
  log "activated version ${version}"
  return 0
}

# Alte Versionen aufräumen (Cache-Management)
cleanup_old_versions() {
  local max_versions="${1:-2}"
  local current_version="$2"

  # Alle Versionen nach Änderungszeit sortiert
  local versions=($(ls -t "${CACHE_DIR}" 2>/dev/null))
  local count=0

  for version in "${versions[@]}"; do
    ((count++))
    # Behalte max_versions neueste, lösche Rest (außer current)
    if [ "${count}" -gt "${max_versions}" ] && [ "${version}" != "${current_version}" ]; then
      log "removing old cached version: ${version}"
      rm -rf "${CACHE_DIR}/${version}"
    fi
  done

  log "cache cleanup complete (keeping ${max_versions} versions)"
}

# ============================================================================
# PHASE 4: Snapshot-Integration (v1.0.0)
# ============================================================================

# Snapshot-Version ermitteln (letzte Version vor Snapshot)
get_snapshot_version() {
  if [ -f "${META_DIR}/snapshot_version" ]; then
    cat "${META_DIR}/snapshot_version"
  else
    echo ""
  fi
}

# Snapshot-Restore erkennen
# Logik: Wenn last_run_version fehlt oder nicht mit snapshot_version übereinstimmt,
# wurde ein Snapshot restored (last_run_version wird erst nach erfolgreichem Start geschrieben)
is_snapshot_restore() {
  local last_run=""
  local snapshot_ver=""

  # last_run_version lesen
  if [ -f "${META_DIR}/last_run_version" ]; then
    last_run="$(cat "${META_DIR}/last_run_version")"
  fi

  # snapshot_version lesen
  snapshot_ver="$(get_snapshot_version)"

  # Restore erkannt wenn:
  # 1. snapshot_version existiert UND
  # 2. last_run_version fehlt ODER unterschiedlich von snapshot_version
  if [ -n "${snapshot_ver}" ]; then
    if [ -z "${last_run}" ] || [ "${last_run}" != "${snapshot_ver}" ]; then
      echo "true"
      return 0
    fi
  fi

  echo "false"
  return 0
}

# Snapshot-Version für nächsten Boot speichern
save_snapshot_marker() {
  local version="$1"
  echo "${version}" > "${META_DIR}/snapshot_version"
  log "snapshot marker saved: ${version}"
}

# ============================================================================
# PHASE 5: HA Notifications (v1.0.0)
# ============================================================================

# Home Assistant Persistent Notification senden
send_ha_notification() {
  local title="$1"
  local message="$2"
  local notification_id="${3:-clawdbot_notification}"

  # SUPERVISOR_TOKEN muss vorhanden sein
  if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
    log "supervisor token not available, skipping notification"
    return 1
  fi

  # Escape JSON strings
  local escaped_title="$(printf '%s' "${title}" | sed 's/"/\\"/g' | sed "s/'/\\'/g")"
  local escaped_message="$(printf '%s' "${message}" | sed 's/"/\\"/g' | sed "s/'/\\'/g")"

  # Send notification via Supervisor API
  local response
  response=$(curl -sSL -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"message\":\"${escaped_message}\",\"title\":\"${escaped_title}\",\"notification_id\":\"${notification_id}\"}" \
    http://supervisor/core/api/services/persistent_notification/create 2>/dev/null || echo "000")

  local http_code
  http_code=$(echo "${response}" | tail -1)

  if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
    log "ha notification sent: ${title}"
    return 0
  else
    log "failed to send ha notification (http ${http_code})"
    return 1
  fi
}

# ============================================================================
# SSH Setup
# ============================================================================
auth_from_opts() {
  local val
  val="$(jq -r .ssh_authorized_keys /data/options.json 2>/dev/null || true)"
  if [ -n "${val}" ] && [ "${val}" != "null" ]; then
    printf "%s" "${val}"
  fi
}

REPO_URL="$(jq -r .repo_url /data/options.json)"
BRANCH="$(jq -r .branch /data/options.json 2>/dev/null || true)"
TOKEN_OPT="$(jq -r .github_token /data/options.json)"

if [ -z "${REPO_URL}" ] || [ "${REPO_URL}" = "null" ]; then
  log "repo_url is empty; set it in add-on options"
  exit 1
fi

# Auth für private Repos (ohne Token-Leaks in Logs/Remote-URL)
GIT_HTTP_EXTRAHEADER=""
if [ -n "${TOKEN_OPT}" ] && [ "${TOKEN_OPT}" != "null" ]; then
  if [[ "${REPO_URL}" == https://* ]]; then
    # GitHub Token Auth via HTTP Header (Token taucht nicht in URL/Logs auf)
    auth_b64="$(printf 'x-access-token:%s' "${TOKEN_OPT}" | base64 | tr -d '\n')"
    GIT_HTTP_EXTRAHEADER="AUTHORIZATION: basic ${auth_b64}"
  else
    log "github_token provided but repo_url is not https; ignoring token"
  fi
fi

SSH_PORT="$(jq -r .ssh_port /data/options.json 2>/dev/null || true)"
SSH_KEYS="$(auth_from_opts || true)"
SSH_PORT_FILE="${STATE_DIR}/ssh_port"
SSH_KEYS_FILE="${STATE_DIR}/ssh_authorized_keys"

if [ -z "${SSH_PORT}" ] || [ "${SSH_PORT}" = "null" ]; then
  if [ -f "${SSH_PORT_FILE}" ]; then
    SSH_PORT="$(cat "${SSH_PORT_FILE}")"
  else
    SSH_PORT="2222"
  fi
fi

if [ -z "${SSH_KEYS}" ] || [ "${SSH_KEYS}" = "null" ]; then
  if [ -f "${SSH_KEYS_FILE}" ]; then
    SSH_KEYS="$(cat "${SSH_KEYS_FILE}")"
  fi
fi

if [ -n "${SSH_KEYS}" ] && [ "${SSH_KEYS}" != "null" ]; then
  printf "%s\n" "${SSH_PORT}" > "${SSH_PORT_FILE}"
  printf "%s\n" "${SSH_KEYS}" > "${SSH_KEYS_FILE}"
  chmod 700 "${SSH_AUTH_DIR}"
  printf "%s\n" "${SSH_KEYS}" > "${SSH_AUTH_DIR}/authorized_keys"
  chmod 600 "${SSH_AUTH_DIR}/authorized_keys"

  mkdir -p /var/run/sshd
  cat > /etc/ssh/sshd_config <<EOF_SSH
Port ${SSH_PORT}
Protocol 2
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile ${SSH_AUTH_DIR}/authorized_keys
ChallengeResponseAuthentication no
ClientAliveInterval 30
ClientAliveCountMax 3
EOF_SSH

  ssh-keygen -A
  /usr/sbin/sshd -e -f /etc/ssh/sshd_config
  log "sshd listening on ${SSH_PORT}"
else
  log "sshd disabled (no authorized keys)"
fi

if [ "${BRANCH}" = "null" ]; then
  BRANCH=""
fi

if [ -n "${BRANCH}" ]; then
  log "branch=${BRANCH}"
fi

# ============================================================================
# PHASE 3 & 4: Update-System & Snapshot-Integration (v1.0.0)
# ============================================================================

# Update-Optionen aus config.json einlesen
UPDATE_MODE="$(jq -r '.update_mode // "stable"' /data/options.json 2>/dev/null || echo 'stable')"
PINNED_VERSION="$(jq -r '.pinned_version // ""' /data/options.json 2>/dev/null || echo '')"
MAX_VERSIONS="$(jq -r '.max_cached_versions // 2' /data/options.json 2>/dev/null || echo '2')"
AUTO_CLEANUP="$(jq -r '.auto_cleanup_versions // true' /data/options.json 2>/dev/null || echo 'true')"

log "update_mode=${UPDATE_MODE}"
[ -n "${PINNED_VERSION}" ] && [ "${PINNED_VERSION}" != "null" ] && log "pinned_version=${PINNED_VERSION}"

# ============================================================================
# PHASE 4: Snapshot-Restore Detection (VOR Update-Check!)
# ============================================================================
IS_SNAPSHOT_RESTORE="$(is_snapshot_restore)"
SNAPSHOT_VER="$(get_snapshot_version)"

if [ "${IS_SNAPSHOT_RESTORE}" = "true" ]; then
  log "snapshot restore detected!"

  if [ -n "${SNAPSHOT_VER}" ] && [ -d "${CACHE_DIR}/${SNAPSHOT_VER}" ]; then
    log "using cached version from snapshot: ${SNAPSHOT_VER}"

    # Aktiviere die gecachte Version aus dem Snapshot
    if activate_version "${SNAPSHOT_VER}"; then
      CURRENT_VER="${SNAPSHOT_VER}"

      # Updates nach Restore deaktivieren (Snapshot-Zustand bewahren)
      UPDATE_MODE="disabled"
      log "updates disabled after snapshot restore (preserving restored state)"

      # Snapshot-Marker aktualisieren
      save_snapshot_marker "${CURRENT_VER}"

      # Arbeitsverzeichnis setzen und mit Gateway starten fortfahren
      cd "${SOURCE_DIR}/active" 2>/dev/null || cd "${REPO_DIR}"
    else
      log "failed to activate snapshot version ${SNAPSHOT_VER}, will rebuild"
      IS_SNAPSHOT_RESTORE="false"
    fi
  else
    log "no cached version ${SNAPSHOT_VER} in snapshot, will rebuild from source"
    IS_SNAPSHOT_RESTORE="false"
  fi
fi

# ============================================================================
# Normal Boot (kein Snapshot-Restore) - Update-System
# ============================================================================
if [ "${IS_SNAPSHOT_RESTORE}" != "true" ]; then
  # Source-Repo sicherstellen (immer aktuell halten für Updates)
  if [ ! -d "${REPO_DIR}/.git" ]; then
    log "cloning repo ${REPO_URL} -> ${REPO_DIR}"
    rm -rf "${REPO_DIR}"
    if [ -n "${BRANCH}" ]; then
      if [ -n "${GIT_HTTP_EXTRAHEADER}" ]; then
        git -c http.extraheader="${GIT_HTTP_EXTRAHEADER}" clone --branch "${BRANCH}" "${REPO_URL}" "${REPO_DIR}"
      else
        git clone --branch "${BRANCH}" "${REPO_URL}" "${REPO_DIR}"
      fi
    else
      if [ -n "${GIT_HTTP_EXTRAHEADER}" ]; then
        git -c http.extraheader="${GIT_HTTP_EXTRAHEADER}" clone "${REPO_URL}" "${REPO_DIR}"
      else
        git clone "${REPO_URL}" "${REPO_DIR}"
      fi
    fi

    # Origin immer ohne Token speichern
    git -C "${REPO_DIR}" remote set-url origin "${REPO_URL}"
  else
    log "updating repo in ${REPO_DIR}"
    git -C "${REPO_DIR}" remote set-url origin "${REPO_URL}"
    if [ -n "${GIT_HTTP_EXTRAHEADER}" ]; then
      git -C "${REPO_DIR}" -c http.extraheader="${GIT_HTTP_EXTRAHEADER}" fetch --prune --tags origin
    else
      git -C "${REPO_DIR}" fetch --prune --tags origin
    fi
  fi

  # Aktuelle Version ermitteln
  CURRENT_VER="$(get_current_version)"
  if [ -z "${CURRENT_VER}" ]; then
    # Keine Version gespeichert - erste Installation oder Migration
    cd "${REPO_DIR}"
    if [ -n "${BRANCH}" ]; then
      git checkout "${BRANCH}" 2>/dev/null || git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
    fi
    CURRENT_VER="$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)"
    log "no current version, detected: ${CURRENT_VER}"
  fi

  # Update-Check durchführen
  NEW_VERSION=""
  if [ "${UPDATE_MODE}" != "disabled" ]; then
    NEW_VERSION="$(check_for_updates "${CURRENT_VER}" "${UPDATE_MODE}" "${PINNED_VERSION}" || echo '')"
  fi

  # Update-Logic
  if [ -n "${NEW_VERSION}" ] && [ "${NEW_VERSION}" != "${CURRENT_VER}" ]; then
    if [ "${UPDATE_MODE}" = "notify" ]; then
      log "update available: ${CURRENT_VER} → ${NEW_VERSION}, awaiting approval"

      # HA Notification senden
      send_ha_notification \
        "Clawdbot Update Available" \
        "Version ${NEW_VERSION} is available. Current: ${CURRENT_VER}. Change update_mode to install automatically." \
        "clawdbot_update_available"

      # Nicht automatisch updaten, bleibe auf aktueller Version
    else
      log "auto-updating to ${NEW_VERSION}"
      if download_and_build_version "${NEW_VERSION}"; then
        if activate_version "${NEW_VERSION}"; then
          CURRENT_VER="${NEW_VERSION}"
          log "successfully updated to ${NEW_VERSION}"

          # HA Notification über erfolgreichen Update senden
          send_ha_notification \
            "Clawdbot Updated" \
            "Successfully updated to version ${NEW_VERSION}" \
            "clawdbot_updated"

          # Cleanup alte Versionen
          [ "${AUTO_CLEANUP}" = "true" ] && cleanup_old_versions "${MAX_VERSIONS}" "${CURRENT_VER}"
        else
          log "failed to activate ${NEW_VERSION}, staying on ${CURRENT_VER}"

          # HA Notification über fehlgeschlagene Aktivierung
          send_ha_notification \
            "Clawdbot Update Failed" \
            "Failed to activate version ${NEW_VERSION}, staying on ${CURRENT_VER}" \
            "clawdbot_update_failed"
        fi
      else
        log "update to ${NEW_VERSION} failed, staying on ${CURRENT_VER}"

        # HA Notification über fehlgeschlagenen Build
        send_ha_notification \
          "Clawdbot Update Failed" \
          "Failed to build version ${NEW_VERSION}, staying on ${CURRENT_VER}" \
          "clawdbot_update_failed"
      fi
    fi
  else
    log "using version: ${CURRENT_VER}"
  fi

  # Aktuelle Version cachen falls nicht vorhanden
  if [ ! -d "${CACHE_DIR}/${CURRENT_VER}" ]; then
    log "current version ${CURRENT_VER} not cached, building"
    cd "${REPO_DIR}"
    git checkout "${CURRENT_VER}" 2>/dev/null || {
      if [ -n "${BRANCH}" ]; then
        git checkout "${BRANCH}" 2>/dev/null || git checkout main 2>/dev/null || true
      else
        git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
      fi
    }
    download_and_build_version "${CURRENT_VER}"
  fi

  # Version aktivieren
  if ! activate_version "${CURRENT_VER}"; then
    log "failed to activate version ${CURRENT_VER}"
    exit 1
  fi

  # Snapshot-Marker für nächsten Boot speichern
  save_snapshot_marker "${CURRENT_VER}"

  # Arbeitsverzeichnis: Aktivierte Version verwenden
  cd "${SOURCE_DIR}/active" 2>/dev/null || {
    log "active version not found, falling back to repo"
    cd "${REPO_DIR}"
  }
fi

# Clawdbot Setup (nur bei erster Installation)
if [ ! -f "${CONFIG_PATH}" ]; then
  log "running clawdbot setup"
  pnpm clawdbot setup --workspace "${WORKSPACE_DIR}"
else
  log "config exists; skipping clawdbot setup"
fi

# ============================================================================
# Gateway Configuration Helpers
# ============================================================================
ensure_gateway_mode() {
  node -e "const fs=require('fs');const JSON5=require('json5');const p=process.env.CLAWDBOT_CONFIG_PATH;const raw=fs.readFileSync(p,'utf8');const data=JSON5.parse(raw);const gateway=data.gateway||{};const mode=String(gateway.mode||'').trim();if(!mode){gateway.mode='local';data.gateway=gateway;fs.writeFileSync(p, JSON.stringify(data,null,2)+'\\n');console.log('updated');}else{console.log('unchanged');}" 2>/dev/null
}

read_gateway_mode() {
  node -e "const fs=require('fs');const JSON5=require('json5');const p=process.env.CLAWDBOT_CONFIG_PATH;const raw=fs.readFileSync(p,'utf8');const data=JSON5.parse(raw);const gateway=data.gateway||{};const mode=String(gateway.mode||'').trim();if(mode){console.log(mode);}"; 2>/dev/null
}

ensure_log_file() {
  node -e "const fs=require('fs');const JSON5=require('json5');const p=process.env.CLAWDBOT_CONFIG_PATH;const raw=fs.readFileSync(p,'utf8');const data=JSON5.parse(raw);const logging=data.logging||{};const file=String(logging.file||'').trim();if(!file){logging.file='/tmp/clawdbot/clawdbot.log';data.logging=logging;fs.writeFileSync(p, JSON.stringify(data,null,2)+'\\n');console.log('updated');}else{console.log('unchanged');}" 2>/dev/null
}

read_log_file() {
  node -e "const fs=require('fs');const JSON5=require('json5');const p=process.env.CLAWDBOT_CONFIG_PATH;const raw=fs.readFileSync(p,'utf8');const data=JSON5.parse(raw);const logging=data.logging||{};const file=String(logging.file||'').trim();if(file){console.log(file);}"; 2>/dev/null
}

if [ -f "${CONFIG_PATH}" ]; then
  mode_status="$(ensure_gateway_mode || true)"
  if [ "${mode_status}" = "updated" ]; then
    log "gateway.mode set to local (missing)"
  elif [ "${mode_status}" = "unchanged" ]; then
    log "gateway.mode already set"
  else
    log "failed to normalize gateway.mode (invalid config?)"
  fi
fi

LOG_FILE="/tmp/clawdbot/clawdbot.log"
if [ -f "${CONFIG_PATH}" ]; then
  log_status="$(ensure_log_file || true)"
  if [ "${log_status}" = "updated" ]; then
    log "logging.file set to ${LOG_FILE} (missing)"
  elif [ "${log_status}" = "unchanged" ]; then
    read_log="$(read_log_file || true)"
    if [ -n "${read_log}" ]; then
      LOG_FILE="${read_log}"
    fi
  else
    log "failed to normalize logging.file (invalid config?)"
  fi
fi

# ============================================================================
# Gateway Options
# ============================================================================
PORT="$(jq -r .port /data/options.json)"
VERBOSE="$(jq -r .verbose /data/options.json)"
LOG_FORMAT="$(jq -r '.log_format // empty' /data/options.json 2>/dev/null || true)"
LOG_COLOR="$(jq -r '.log_color // empty' /data/options.json 2>/dev/null || true)"
LOG_FIELDS="$(jq -r '.log_fields // empty' /data/options.json 2>/dev/null || true)"

if [ -z "${LOG_FORMAT}" ] || [ "${LOG_FORMAT}" = "null" ]; then
  LOG_FORMAT="pretty"
fi
if [ -z "${LOG_COLOR}" ] || [ "${LOG_COLOR}" = "null" ]; then
  LOG_COLOR="false"
fi
if [ -z "${LOG_FIELDS}" ] || [ "${LOG_FIELDS}" = "null" ]; then
  LOG_FIELDS=""
fi
if [ "${LOG_FORMAT}" != "pretty" ] && [ "${LOG_FORMAT}" != "raw" ]; then
  log "log_format=${LOG_FORMAT} is invalid; using pretty"
  LOG_FORMAT="pretty"
fi

if [ -z "${PORT}" ] || [ "${PORT}" = "null" ]; then
  PORT="18789"
fi

ALLOW_UNCONFIGURED=()
if [ ! -f "${CONFIG_PATH}" ]; then
  log "config missing; allowing unconfigured gateway start"
  ALLOW_UNCONFIGURED=(--allow-unconfigured)
else
  gateway_mode="$(read_gateway_mode || true)"
  if [ -z "${gateway_mode}" ]; then
    log "gateway.mode missing; allowing unconfigured gateway start"
    ALLOW_UNCONFIGURED=(--allow-unconfigured)
  fi
fi

ARGS=(gateway "${ALLOW_UNCONFIGURED[@]}" --port "${PORT}")
if [ "${VERBOSE}" = "true" ]; then
  ARGS+=(--verbose)
fi

# ============================================================================
# Signal Handlers & Log Formatting
# ============================================================================
child_pid=""
tail_pid=""

forward_usr1() {
  if [ -n "${child_pid}" ]; then
    if ! pkill -USR1 -P "${child_pid}" 2>/dev/null; then
      kill -USR1 "${child_pid}" 2>/dev/null || true
    fi
    log "forwarded SIGUSR1 to gateway process"
  fi
}

shutdown_child() {
  if [ -n "${tail_pid}" ]; then
    kill -TERM "${tail_pid}" 2>/dev/null || true
  fi
  if [ -n "${child_pid}" ]; then
    kill -TERM "${child_pid}" 2>/dev/null || true
  fi
}

format_log_stream() {
  local format="$1"
  local use_color="$2"
  local fields="$3"

  if [ "${format}" != "pretty" ]; then
    cat
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    cat
    return
  fi

  local jq_color="false"
  if [ "${use_color}" = "true" ]; then
    jq_color="true"
  fi

  jq -Rr --argjson use_color "${jq_color}" --arg fields "${fields}" '
    def trim: gsub("^\\s+|\\s+$"; "");
    def parse_name($raw):
      if ($raw|type) == "string" then (try ($raw|fromjson) catch null) else null end;
    def render($v):
      if ($v|type) == "string" then $v
      elif ($v|type) == "number" or ($v|type) == "boolean" then ($v|tostring)
      else ($v|tojson)
      end;
    def numeric_entries($obj):
      ($obj | to_entries | map(select(.key|test("^\\d+$"))) | sort_by(.key|tonumber));
    def string_parts($obj; $name):
      (numeric_entries($obj) | map(.value) | map(select(type=="string")) | map(select(. != $name)));
    def object_meta($obj):
      (numeric_entries($obj) | map(.value) | map(select(type=="object")) | reduce .[] as $o ({}; . * $o));
    def colorize($text; $level):
      if $use_color then
        (if $level == "ERROR" or $level == "FATAL" then "\u001b[31m"+$text+"\u001b[0m"
         elif $level == "WARN" then "\u001b[33m"+$text+"\u001b[0m"
         elif $level == "DEBUG" or $level == "TRACE" then "\u001b[90m"+$text+"\u001b[0m"
         else "\u001b[36m"+$text+"\u001b[0m"
         end)
      else $text end;
    def collect_fields($meta; $fields):
      [ $fields[] | select($meta[.] != null) | "\(. )=\(render($meta[.]))" ];
    def format_line($time; $level; $tag; $message; $fields):
      ([ $time, (colorize($level; $level)), $tag ] | map(select(. != null and . != "")) | join(" "))
      + (if $message != "" then " - " + $message else "" end)
      + (if ($fields|length) > 0 then " | " + ($fields|join(" ")) else "" end);
    . as $line
    | (fromjson? // null) as $obj
    | if $obj == null then $line
      else
        ($obj._meta // {}) as $meta
        | ($meta.name // null) as $name
        | (parse_name($name) // {}) as $name_meta
        | (object_meta($obj) + $name_meta) as $merged
        | ($fields | split(",") | map(trim) | map(select(length>0))) as $field_list
        | (string_parts($obj; $name) | join(" ")) as $message
        | if ($message|length) == 0 then $line
          else
            ($obj.time // $meta.date // "") as $time
            | ($meta.logLevelName // "INFO" | tostring | ascii_upcase) as $level
            | ($name_meta.subsystem // $name_meta.module // "") as $tag
            | format_line($time; $level; $tag; $message; collect_fields($merged; $field_list))
          end
      end
  '
}

start_log_tail() {
  local file="$1"
  (
    while [ ! -f "${file}" ]; do
      sleep 1
    done
    tail -n +1 -F "${file}" | format_log_stream "${LOG_FORMAT}" "${LOG_COLOR}" "${LOG_FIELDS}"
  ) &
  tail_pid=$!
}

trap forward_usr1 USR1
trap shutdown_child TERM INT

# ============================================================================
# Gateway Main Loop
# ============================================================================
while true; do
  pnpm clawdbot "${ARGS[@]}" &
  child_pid=$!
  start_log_tail "${LOG_FILE}"
  set +e
  wait "${child_pid}"
  status=$?
  set -e
  if [ -n "${tail_pid}" ]; then
    kill -TERM "${tail_pid}" 2>/dev/null || true
    tail_pid=""
  fi

  if [ "${status}" -eq 0 ]; then
    log "gateway exited cleanly"
    break
  elif [ "${status}" -eq 129 ]; then
    log "gateway exited after SIGUSR1; restarting"
    continue
  else
    log "gateway exited uncleanly (status=${status}); restarting"
    continue
  fi
done

exit "${status}"
