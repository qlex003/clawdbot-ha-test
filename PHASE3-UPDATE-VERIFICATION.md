# PHASE 3: Update-System - Verifikation

## Setup-UI (Ingress) - Verifikation (OAuth/API Keys ohne SSH)

**Ziel:** Sicherstellen, dass die optionale Setup-Seite (`easy_setup_ui`) funktioniert und der normale Betrieb unverändert bleibt.

### Voraussetzungen
- Add-on installiert & gestartet
- In den Add-on Optionen:
  - `easy_setup_ui: true` (für Setup-Tests)
  - optional: `update_mode: stable`

### Testfälle
- [ ] **Ingress erreichbar**: Add-ons → Clawdbot Gateway → **OPEN WEB UI**
- [ ] **Setup-Seite erreichbar**: im Ingress `/__setup/` öffnen
- [ ] **Wizard RPC erreichbar**:
  - [ ] „Wizard starten“ zeigt eine Antwort (kein 502)
  - [ ] „Status“ zeigt den aktuellen Wizard-State
  - [ ] „Weiter“ funktioniert (wenn der Wizard Actions/Choices liefert)
  - [ ] „Abbrechen“ beendet den Wizard-State
- [ ] **API-Key Save**:
  - [ ] Anthropic/OpenAI Key speichern → Erfolgsmeldung
  - [ ] Datei existiert: `/config/clawdbot/data/state/.env`
  - [ ] Keine Secrets im Add-on Log (Keys dürfen niemals im Klartext auftauchen)
- [ ] **Transparenter Proxy** (Regression):
  - [ ] `easy_setup_ui: false` setzen, Add-on neu starten
  - [ ] OPEN WEB UI zeigt weiterhin die normale Control UI

## Implementierte Features

### ✅ Task 13: config.json Update-Modi
**Datei:** [clawdbot_gateway/config.json](clawdbot_gateway/config.json)

**Neue Optionen:**
```json
{
  "update_mode": "stable",           // disabled|notify|stable|latest
  "pinned_version": "",              // Gepinnte Version (optional)
  "auto_cleanup_versions": true,     // Automatisches Cleanup
  "max_cached_versions": 2           // Anzahl gecachter Versionen
}
```

**Schema-Validierung:**
- `update_mode`: `list(disabled|notify|stable|latest)?`
- `pinned_version`: `str?`
- `auto_cleanup_versions`: `bool?`
- `max_cached_versions`: `int(1,10)?`

---

### ✅ Tasks 14-18: Update-Funktionen
**Datei:** [clawdbot_gateway/run.sh](clawdbot_gateway/run.sh) (Zeilen 172-379)

**Implementierte Funktionen:**

#### 1. `get_current_version()`
- Liest aktuelle Version aus `.meta/current_version`
- Return: Version-String oder leer

#### 2. `set_current_version(version)`
- Speichert Version in `.meta/current_version` und `.meta/last_run_version`
- Logging der gesetzten Version

#### 3. `check_for_updates(current, mode, pinned)`
- Prüft ob neue Version verfügbar
- Respektiert Update-Modi:
  - `disabled`: Keine Updates
  - `stable`: Nur stable Releases (keine alpha/beta/rc)
  - `latest`: Alle Releases inkl. Pre-Releases
- Gepinnte Version hat Priorität
- Return: Neue Version oder nichts

#### 4. `download_and_build_version(version)`
- Isolierter Build in `/tmp/clawdbot-build-${version}-$$`
- Dependencies installieren (`pnpm install`)
- Gateway bauen (`pnpm build`)
- UI bauen (`pnpm ui:build`)
- **Smoke-Test**: `node dist/index.js --version` (10s timeout)
- Cache-Speicherung in `${CACHE_DIR}/${version}/`
- Cleanup bei Fehler
- Return: 0 (Erfolg) oder 1 (Fehler)

#### 5. `activate_version(version)`
- Symlink/Kopie von Cache zu `${SOURCE_DIR}/active`
- Setzt aktuelle Version via `set_current_version()`
- Return: 0 (Erfolg) oder 1 (Fehler)

#### 6. `cleanup_old_versions(max, current)`
- Löscht alte gecachte Versionen
- Behält `max_versions` neueste
- Schützt `current_version`
- Logging der gelöschten Versionen

---

### ✅ Task 19: Update-Logic Integration
**Datei:** [clawdbot_gateway/run.sh](clawdbot_gateway/run.sh) (Zeilen 459-563)

**Ablauf:**

```
1. Optionen einlesen (update_mode, pinned_version, etc.)
   ↓
2. Source-Repo clonen/updaten (git fetch --tags)
   ↓
3. Aktuelle Version ermitteln (get_current_version oder git describe)
   ↓
4. Update-Check (check_for_updates)
   ↓
5. WENN neue Version verfügbar:
   ├─ notify Mode: Log + TODO HA Notification
   └─ stable/latest Mode:
      ├─ download_and_build_version()
      ├─ activate_version()
      ├─ cleanup_old_versions()
      └─ Log Erfolg/Fehler
   ↓
6. Aktuelle Version cachen (falls nicht vorhanden)
   ↓
7. Version aktivieren (activate_version)
   ↓
8. Arbeitsverzeichnis wechseln (${SOURCE_DIR}/active)
   ↓
9. Clawdbot Setup (nur bei erster Installation)
```

**Wichtige Änderungen:**
- ❌ **Alt:** `git pull` + `git reset --hard` + direkter Build
- ✅ **Neu:** Isolierter Build → Smoke-Test → Cache → Aktivierung
- ✅ Fehlerbehandlung: Bei Fehler bleibt alte Version aktiv
- ✅ Version-Tracking in `.meta/`

---

## Verifikations-Checkliste

### Manuelle Tests auf HA-System

#### Test 1: Fresh Install
```bash
# 1. Add-on installieren (erste Installation)
# 2. Logs prüfen
ha addons logs local_clawdbot

# Erwartete Logs:
# [addon] run.sh version=2026-01-24-v1.0.0-update-system
# [addon] update_mode=stable
# [addon] no current version, detected: <version>
# [addon] using version: <version>
# [addon] downloading and building version <version>
# [addon] installing dependencies for <version>
# [addon] building gateway for <version>
# [addon] building UI for <version>
# [addon] smoke testing <version>
# [addon] version <version> built and cached successfully
# [addon] version set to <version>
# [addon] activated version <version>

# 3. Verzeichnisse prüfen
ssh -p 2222 root@<HA-IP>
ls -la /config/clawdbot/
ls /config/clawdbot/cache/          # Sollte eine Version enthalten
ls /config/clawdbot/.meta/
cat /config/clawdbot/.meta/current_version
ls -l /config/clawdbot/source/active  # Symlink zu cache/<version>
```

#### Test 2: Update-Modi
```bash
# Test 2a: disabled Mode
# 1. Add-on Config ändern: update_mode = "disabled"
# 2. Restart Add-on
# 3. Logs prüfen:
ha addons logs local_clawdbot | grep update
# Erwartung: Keine Updates, bleibt auf aktueller Version

# Test 2b: notify Mode
# 1. Add-on Config ändern: update_mode = "notify"
# 2. Neue Version im Repo verfügbar machen
# 3. Restart Add-on
# 4. Logs prüfen:
# Erwartung: "update available: <old> → <new>, awaiting approval"

# Test 2c: stable Mode (default)
# 1. Add-on Config ändern: update_mode = "stable"
# 2. Neue stable Version im Repo (Tag ohne alpha/beta/rc)
# 3. Restart Add-on
# 4. Logs prüfen:
# Erwartung: Automatisches Update auf neue Version

# Test 2d: latest Mode
# 1. Add-on Config ändern: update_mode = "latest"
# 2. Pre-Release verfügbar (Tag mit alpha/beta/rc)
# 3. Restart Add-on
# 4. Logs prüfen:
# Erwartung: Update auch auf Pre-Release
```

#### Test 3: Version-Pinning
```bash
# 1. Add-on Config ändern:
#    - update_mode = "stable"
#    - pinned_version = "v0.2.14"
# 2. Restart Add-on
# 3. Logs prüfen
ha addons logs local_clawdbot | grep pinned_version
# Erwartung: "pinned_version=v0.2.14"
# Version wechselt zu v0.2.14 (falls vorhanden)

# 4. Verifikation
ssh -p 2222 root@<HA-IP>
cat /config/clawdbot/.meta/current_version
# Sollte "v0.2.14" sein
```

#### Test 4: Cache-Management
```bash
# 1. Mehrere Versionen installieren (z.B. durch updates)
# 2. max_cached_versions = 2 setzen
# 3. Restart nach 3. Update
# 4. Cache prüfen
ssh -p 2222 root@<HA-IP>
ls /config/clawdbot/cache/
# Erwartung: Nur 2 Versionen (neueste + eine alte)

# 5. Logs prüfen
ha addons logs local_clawdbot | grep "removing old cached"
# Sollte gelöschte Versionen zeigen
```

#### Test 5: Smoke-Test-Fehlerbehandlung
```bash
# Test: Kaputte Version simulieren
# 1. Fake-Version erstellen die Smoke-Test failet
ssh -p 2222 root@<HA-IP>
cd /config/clawdbot/source/clawdbot-src
git tag -a v99.99.99-broken -m "Broken version for testing"
git push --tags  # Falls remote

# 2. Add-on Config:
#    - pinned_version = "v99.99.99-broken"
# 3. Restart Add-on
# 4. Logs prüfen
ha addons logs local_clawdbot | grep smoke
# Erwartung: "smoke test failed for v99.99.99-broken"
# Fallback auf alte Version: "staying on <old_version>"
```

---

## Automatisierte Syntax-Prüfung

```bash
# Bash-Syntax prüfen
bash -n clawdbot_gateway/run.sh
# Kein Output = Syntax OK

# JSON-Syntax prüfen
jq . clawdbot_gateway/config.json
# Sollte formatiertes JSON ausgeben
```

---

## Success Criteria (Task 20)

### ✅ Implementierung
- [x] config.json mit allen Update-Optionen
- [x] Alle 6 Update-Funktionen implementiert
- [x] Update-Logic in run.sh integriert
- [x] run.sh Version aktualisiert (2026-01-24-v1.0.0-update-system)

### 🧪 Manuelle Tests (auf HA-System durchführen)
- [ ] Fresh Install funktioniert
- [ ] Update-Mode "disabled" funktioniert
- [ ] Update-Mode "notify" zeigt verfügbare Updates
- [ ] Update-Mode "stable" updatet automatisch (nur stable)
- [ ] Update-Mode "latest" updatet inkl. Pre-Releases
- [ ] Version-Pinning funktioniert
- [ ] Cache-Management bereinigt alte Versionen
- [ ] Smoke-Tests verhindern kaputte Aktivierungen
- [ ] Fehlerbehandlung: Rollback bei fehlgeschlagenem Build

### 📊 Performance
- [ ] Build-Zeit: < 15 Minuten (erste Installation)
- [ ] Update-Zeit: < 10 Minuten (mit Cache)
- [ ] Smoke-Test: < 10 Sekunden
- [ ] Kein Memory-Leak durch Temp-Verzeichnisse

---

## Bekannte Einschränkungen

### Phase 3 TODO (für Phase 5):
- HA Notifications bei `update_mode: notify` noch nicht implementiert
  - Zeile 509 in run.sh: `# TODO: HA Notification senden (Phase 5)`
  - Wird in PHASE 5 (HA-Integration) nachgeholt

### Potentielle Probleme:
1. **Disk-Space:** Multiple Versionen im Cache benötigen Speicher
   - Mitigation: `max_cached_versions` begrenzt (default: 2)
   - User kann via `auto_cleanup_versions: true` automatisch bereinigen

2. **Lange Build-Zeiten:** Erste Installation ~10-15 Min
   - Unvermeidbar (Dependencies + Build + UI)
   - Nachfolgende Updates nutzen Cache

3. **Git-Tag-Format:** Code erwartet `v1.2.3` oder commit-hash
   - Pre-Release Erkennung via Regex: `(alpha|beta|rc)`
   - Nicht-Standard-Tags könnten fehlschlagen

---

## Nächste Schritte

### Sofort:
1. ✅ PHASE 3 als abgeschlossen markieren
2. 🔜 Manuelle Tests auf HA-System durchführen
3. 🔜 Bugs fixen falls Tests fehlschlagen

### Diese Woche:
- **PHASE 4:** Snapshot-Integration (Gruppe 5, Tasks 21-25)
  - Benötigt funktionierende Update-System

### Optional parallel:
- **PHASE 5:** HA-Integration (Gruppe 6, Tasks 26-31)
  - Kann parallel zu Phase 4 laufen

---

## Dokumentation für User

### Update-Modi erklärt:

| Modus | Beschreibung | Use-Case |
|-------|--------------|----------|
| `disabled` | Keine Updates | Manuelle Kontrolle, Entwicklung |
| `notify` | Notification bei Updates | User entscheidet wann zu updaten |
| `stable` | Auto-Update nur stable | **DEFAULT** - Produktiv-Systeme |
| `latest` | Auto-Update inkl. Pre-Releases | Testing, Early-Adopters |

### Beispiel-Konfiguration:

```yaml
# HA Add-on Config (Supervisor UI)
update_mode: stable              # Empfohlen für Produktion
pinned_version: ""               # Leer = neueste Version
auto_cleanup_versions: true      # Automatisch alte Versionen löschen
max_cached_versions: 2           # 2 = aktuell + 1 alte (Rollback)
```

### Manuelle Version-Wechsel:

```bash
# Via SSH zum Add-on
ssh -p 2222 root@<HA-IP>

# Verfügbare Versionen anzeigen
ls /config/clawdbot/cache/

# Zu bestimmter Version wechseln (z.B. Rollback)
# 1. In Add-on Config setzen: pinned_version = "v0.2.14"
# 2. Add-on restart
# ODER direkt via CLI (Advanced):
# activate_version "v0.2.14"  # Funktion aus run.sh
```

---

**Status:** PHASE 3 ABGESCHLOSSEN ✅

**Commit Message:**
```
feat(update-system): implement complete update system with rollback (PHASE 3)

- Add update-mode config options (disabled|notify|stable|latest)
- Implement version-tracking functions (get/set current version)
- Add isolated build system with smoke-tests
- Implement cache management with cleanup
- Add automatic update-check and activation
- Support version-pinning for manual control
- Update run.sh to version 2026-01-24-v1.0.0-update-system

BREAKING: New cache directory structure requires storage-reorg (PHASE 2)
TODO: HA notifications for notify mode (PHASE 5)

Tasks: #13-#19 (Gruppe 4)
```
