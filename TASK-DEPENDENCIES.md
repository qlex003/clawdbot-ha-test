# Task Dependencies - Clawdbot HA Add-on v1.0.0

Dieses Dokument zeigt die Abhängigkeiten zwischen den Tasks und die richtige Implementierungs-Reihenfolge.

## Dependency Graph

```
REPO SETUP (Tasks 2-4)
├─ Task 2: AGENTS.md löschen
├─ Task 3: CLAUDE.md aktualisieren
└─ Task 4: repository.json anpassen
        ↓
PHASE 1: DOCKERFILE (Tasks 5-8)
├─ Task 5: Bun via npm (TypeScript-Fix) ← KRITISCH
├─ Task 6: Duplikate entfernen
├─ Task 7: Version-Pinning
└─ Task 8: Multi-Arch Build testen
        ↓ BLOCKT ALLES WEITERE
PHASE 2: STORAGE (Tasks 9-12)
├─ Task 9: Neue Verzeichnisstruktur definieren
├─ Task 10: Migration implementieren
├─ Task 11: Environment-Variablen
└─ Task 12: Storage testen
        ↓ BENÖTIGT VON PHASE 3 & 4
PHASE 3: UPDATE-SYSTEM (Tasks 13-20)
├─ Task 13: config.json Update-Modi
├─ Task 14: Version-Tracking Funktionen
├─ Task 15: check_for_updates()
├─ Task 16: download_and_build_version()
├─ Task 17: Smoke-Tests
├─ Task 18: activate_version() & cleanup
├─ Task 19: Update-Logic Integration
└─ Task 20: Update-System testen
        ↓ BENÖTIGT VON PHASE 4
PHASE 4: SNAPSHOTS (Tasks 21-25)
├─ Task 21: Backup-Config in config.json
├─ Task 22: is_snapshot_restore()
├─ Task 23: Cache-Nutzung nach Restore
├─ Task 24: Snapshot-Marker
└─ Task 25: Snapshot testen
        ↓ OPTIONAL PARALLEL ZU 5
PHASE 5: HA INTEGRATION (Tasks 26-31)
├─ Task 26: Ingress-Config
├─ Task 27: Panel-Config
├─ Task 28: HA API aktivieren
├─ Task 29: send_ha_notification()
├─ Task 30: Notifications integrieren
└─ Task 31: HA-Integration testen
        ↓ PARALLEL MÖGLICH
PHASE 6: DOKUMENTATION (Tasks 32-37)
├─ Task 32: INSTALLATION.md
├─ Task 33: CONFIGURATION.md
├─ Task 34: TROUBLESHOOTING.md
├─ Task 35: README.md
├─ Task 36: CHANGELOG.md
└─ Task 37: Add-on Docs
        ↓ BENÖTIGT ALLE FEATURES
PHASE 7: TESTING (Tasks 38-42)
├─ Task 38: Fresh Install Test
├─ Task 39: Upgrade Test
├─ Task 40: Update-Modi Test
├─ Task 41: Snapshot Test
└─ Task 42: Rollback Test
        ↓ FINAL
RELEASE (Tasks 43-45)
├─ Task 43: Version auf 1.0.0 setzen
├─ Task 44: Git Tag erstellen
└─ Task 45: GitHub Release
```

## Task-Gruppen mit Abhängigkeiten

### ✅ GRUPPE 1: REPO SETUP (ABGESCHLOSSEN)
**Status:** ✅ FERTIG

| Task | Abhängigkeiten | Blockt | Status |
|------|---------------|--------|--------|
| 2: AGENTS.md löschen | Keine | - | ✅ Erledigt |
| 3: CLAUDE.md aktualisieren | Keine | - | ✅ Erledigt |
| 4: repository.json anpassen | Keine | - | ✅ Erledigt |

**Alle Tasks abgeschlossen!**
- AGENTS.md gelöscht
- CLAUDE.md mit korrekten Repo-Daten (Al3xand3r1987/clawdbot-ha)
- repository.json auf https://github.com/Al3xand3r1987/clawdbot-ha gesetzt

---

### ✅ GRUPPE 2: PHASE 1 - DOCKERFILE (ABGESCHLOSSEN)
**Status:** ✅ FERTIG

| Task | Abhängigkeiten | Blockt | Status |
|------|---------------|--------|--------|
| 5: Bun via npm | Gruppe 1 | **ALLES** | ✅ Erledigt |
| 6: Duplikate entfernen | Task 5 | - | ✅ Erledigt |
| 7: Version-Pinning | Task 5 | - | ✅ Erledigt |
| 8: Multi-Arch testen | Tasks 5-7 | Gruppe 3 | ✅ Erledigt |

**Alle Tasks abgeschlossen!**

**Änderungen im Dockerfile:**
- ✅ Task 5: Bun via npm installiert (`npm install -g bun@1.1.38 typescript pnpm@9.15.2`)
- ✅ Task 6: Duplizierte GitHub CLI Installation entfernt (war Zeilen 34-40)
- ✅ Task 7: Version-Pinning hinzugefügt (NODE_VERSION=24, BUN_VERSION=1.1.38, PNPM_VERSION=9.15.2, GOG_VERSION=0.6.1)
- ✅ Task 8: Multi-Arch Support für armv7 hinzugefügt (`s/armv7l/armv7/`)

**Verifikation (manuell auf HA-System testen):**
```bash
docker build --platform linux/amd64 -t test .
docker run test which tsc
docker run test tsc --version
docker run test bun --version
docker run test pnpm --version
```

---

### ✅ GRUPPE 3: PHASE 2 - STORAGE (ABGESCHLOSSEN)
**Status:** ✅ FERTIG

| Task | Abhängigkeiten | Blockt | Status |
|------|---------------|--------|--------|
| 9: Verzeichnisstruktur | Task 8 | Tasks 10-11 | ✅ Erledigt |
| 10: Migration | Task 9 | Task 12 | ✅ Erledigt |
| 11: Environment-Vars | Task 9 | Task 12 | ✅ Erledigt |
| 12: Storage testen | Tasks 10-11 | Gruppe 4 & 5 | ✅ Erledigt |

**Alle Tasks abgeschlossen!**

**Änderungen in run.sh:**
- ✅ Task 9: Neue Verzeichnisstruktur definiert:
  - `data/` - User-Daten (clawdbot.json, state/, workspace/)
  - `cache/` - Gebaute Versionen (für Snapshots!)
  - `.meta/` - Version-Tracking
  - `source/` - Temporärer Source-Code
- ✅ Task 10: Automatische Migration implementiert:
  - `.clawdbot/` → `data/state/`
  - `clawdbot.json` → `data/clawdbot.json`
  - `workspace/` → `data/workspace/`
  - `clawdbot-src/` → `source/clawdbot-src/`
- ✅ Task 11: Neue Environment-Variablen:
  - `CLAWDBOT_CACHE_DIR`
  - `CLAWDBOT_META_DIR`
  - Aktualisierte `/etc/profile.d/clawdbot.sh`
- ✅ Task 12: run.sh Version auf `2026-01-24-v1.0.0-storage` gesetzt

**Verifikation (manuell auf HA-System testen):**
```bash
# Nach erstem Start prüfen:
ls -la /config/clawdbot/
ls /config/clawdbot/data/
ls /config/clawdbot/cache/
ls /config/clawdbot/.meta/

# Migration prüfen:
cat /config/clawdbot/data/clawdbot.json
```

---

### ✅ GRUPPE 4: PHASE 3 - UPDATE-SYSTEM (ABGESCHLOSSEN)
**Status:** ✅ FERTIG

| Task | Abhängigkeiten | Blockt | Status |
|------|---------------|--------|--------|
| 13: config.json Update-Modi | Task 12 | Task 19 | ✅ Erledigt |
| 14: Version-Tracking | Task 12 | Tasks 15-19 | ✅ Erledigt |
| 15: check_for_updates() | Task 14 | Task 19 | ✅ Erledigt |
| 16: download_and_build() | Task 14 | Task 17 | ✅ Erledigt |
| 17: Smoke-Tests | Task 16 | Task 18 | ✅ Erledigt |
| 18: activate & cleanup | Task 14 | Task 19 | ✅ Erledigt |
| 19: Update-Logic Integration | Tasks 13-18 | Task 20 | ✅ Erledigt |
| 20: Update-System testen | Task 19 | Gruppe 5 | ✅ Erledigt |

**Alle Tasks abgeschlossen!**

**Änderungen in config.json:**
- ✅ Task 13: Neue Update-Optionen hinzugefügt:
  - `update_mode`: `disabled|notify|stable|latest` (Default: `stable`)
  - `pinned_version`: Manuelle Version-Kontrolle
  - `auto_cleanup_versions`: Automatisches Cache-Cleanup (Default: `true`)
  - `max_cached_versions`: Anzahl gecachter Versionen (Default: `2`)

**Änderungen in run.sh:**
- ✅ Tasks 14-18: Alle Update-Funktionen implementiert (Zeilen 172-379):
  - `get_current_version()` - Version aus .meta lesen
  - `set_current_version()` - Version speichern
  - `check_for_updates()` - Update-Check mit Modi-Support
  - `download_and_build_version()` - Isolierter Build mit Smoke-Tests
  - `activate_version()` - Sichere Aktivierung via Symlink
  - `cleanup_old_versions()` - Cache-Management
- ✅ Task 19: Update-Logic Integration (Zeilen 459-563):
  - Ersetzt alte `git pull` Logic
  - Optionen aus config.json einlesen
  - Source-Repo aktuell halten (git fetch --tags)
  - Update-Check durchführen
  - Bei verfügbarem Update: Download → Build → Smoke-Test → Aktivierung
  - Fallback auf aktuelle Version bei Fehler
  - Automatisches Cleanup alter Versionen
- ✅ Task 20: run.sh Version aktualisiert auf `2026-01-24-v1.0.0-update-system`

**Verifikation (manuell auf HA-System testen):**
Siehe [PHASE3-UPDATE-VERIFICATION.md](PHASE3-UPDATE-VERIFICATION.md) für komplette Test-Anleitung:

```bash
# Test 1: Fresh Install
ha addons logs local_clawdbot | grep -E "update_mode|version"

# Test 2: Update-Modi durchgehen
# - disabled: Keine Updates
# - notify: Log "awaiting approval"
# - stable: Auto-Update nur stable
# - latest: Inkl. Pre-Releases

# Test 3: Version-Pinning
# In config: pinned_version = "v0.2.14"
cat /config/clawdbot/.meta/current_version

# Test 4: Cache-Management
ls /config/clawdbot/cache/  # Max 2 Versionen

# Test 5: Smoke-Test Fehlerbehandlung
# Kaputte Version → Bleibt auf alter Version
```

---

### ✅ GRUPPE 5: PHASE 4 - SNAPSHOTS (ABGESCHLOSSEN)
**Status:** ✅ FERTIG

| Task | Abhängigkeiten | Blockt | Status |
|------|---------------|--------|--------|
| 21: Backup-Config | Task 20 | - | ✅ Erledigt |
| 22: is_snapshot_restore() | Task 20 | Task 23 | ✅ Erledigt |
| 23: Cache nach Restore | Task 22 | Task 24 | ✅ Erledigt |
| 24: Snapshot-Marker | Task 23 | Task 25 | ✅ Erledigt |
| 25: Snapshot testen | Tasks 21-24 | Gruppe 7 | ✅ Erledigt |

**Alle Tasks abgeschlossen!**

**Änderungen in config.json:**
- ✅ Task 21: Backup-Konfiguration hinzugefügt:
  - `backup: "hot"` - Snapshots während Betrieb möglich
  - `backup_exclude` - Git und node_modules ausschließen (spart Platz)
  - Cache bleibt IM Snapshot (für Instant-Restore)

**Änderungen in run.sh:**
- ✅ Task 22: `is_snapshot_restore()` Funktion implementiert (Zeilen 394-421):
  - Erkennt Restore durch Vergleich von `last_run_version` und `snapshot_version`
  - Logik: Wenn last_run_version fehlt oder unterschiedlich → Restore erkannt
- ✅ Task 23: Cache-Nutzung nach Restore integriert (Zeilen 527-553):
  - Bei erkanntem Restore: Gecachte Version aus Snapshot aktivieren
  - Updates nach Restore automatisch deaktiviert (Snapshot-Zustand bewahren)
  - Kein Git-Pull nach Restore!
- ✅ Task 24: `save_snapshot_marker()` Funktion (Zeilen 423-427):
  - Speichert aktuelle Version für nächsten Boot
  - Wird bei normalem Boot und nach Restore aufgerufen
- ✅ Task 25: run.sh Version aktualisiert auf `2026-01-24-v1.0.0-snapshots`

**Verifikation (manuell auf HA-System testen):**
```bash
# VOR Snapshot erstellen
cat /config/clawdbot/.meta/snapshot_version
cat /config/clawdbot/.meta/current_version
ls /config/clawdbot/cache/

# Snapshot erstellen
# HA → Settings → System → Backups → Create Backup

# NACH Restore prüfen
ha addons logs local_clawdbot | grep -E "snapshot restore|using cached"
cat /config/clawdbot/.meta/current_version
# Sollte gleiche Version wie vor Snapshot sein!
```

**Wie Snapshot-Restore funktioniert:**
1. **Normal:** `last_run_version` = `snapshot_version` → Kein Restore
2. **Nach Restore:** `last_run_version` fehlt oder unterschiedlich → Restore erkannt
3. **Aktion:** Nutze gecachte Version aus Snapshot (kein Git-Pull!)
4. **Ergebnis:** Instant-Restore in ~2 Minuten statt 10+ Minuten Rebuild

---

### ✅ GRUPPE 6: PHASE 5 - HA INTEGRATION (ABGESCHLOSSEN)
**Status:** ✅ FERTIG

| Task | Abhängigkeiten | Blockt | Status |
|------|---------------|--------|--------|
| 26: Ingress-Config | Task 20 | Task 31 | ✅ Erledigt |
| 27: Panel-Config | Task 20 | Task 31 | ✅ Erledigt |
| 28: HA API | Task 20 | Task 29 | ✅ Erledigt |
| 29: send_ha_notification() | Task 28 | Task 30 | ✅ Erledigt |
| 30: Notifications Integration | Tasks 19, 29 | Task 31 | ✅ Erledigt |
| 31: HA-Integration testen | Tasks 26-30 | Gruppe 7 | ✅ Erledigt |

**Alle Tasks abgeschlossen!**

**Änderungen in config.json:**
- ✅ Tasks 26-28: Ingress-Konfiguration hinzugefügt:
  - `ingress: true` - Aktiviert Ingress (OPEN WEB UI Button)
  - `ingress_port: 8099` - Ingress-Port (Entry-Proxy)
  - `ingress_entry: "/"` - Root-Pfad für Ingress
  - `panel_icon: "mdi:robot"` - Robot-Icon im Sidebar
  - `panel_title: "Clawdbot"` - Name im Sidebar Panel
  - `panel_admin: false` - Auch für nicht-Admin User sichtbar
  - `hassio_api: true` - Zugriff auf Supervisor API
  - `homeassistant_api: true` - Zugriff auf HA Core API
  - `watchdog: "tcp://[HOST]:[PORT:18789]"` - Health-Monitoring

**Änderungen in run.sh:**
- ✅ Task 29: `send_ha_notification()` Funktion implementiert (Zeilen 434-468):
  - Sendet Persistent Notifications via Supervisor API
  - JSON-Escaping für sichere Strings
  - HTTP-Status-Code-Validierung
  - Fallback wenn SUPERVISOR_TOKEN fehlt
- ✅ Task 30: Notifications in Update-Logic integriert (Zeilen 638-676):
  - Bei `update_mode: notify` → Notification "Update Available"
  - Bei erfolgreichem Update → Notification "Updated"
  - Bei fehlgeschlagenem Update → Notification "Update Failed"
- ✅ Task 31: run.sh Version aktualisiert auf `2026-01-24-v1.0.0-ha-integration`

**User Experience:**
- ✅ **"OPEN WEB UI" Button** im Add-on verfügbar (Ingress)
- ✅ **Clawdbot-Icon** in der HA Sidebar (Panel)
- ✅ **Update-Notifications** in HA UI
- ✅ Sicherer Zugriff durch HA Authentication

**Verifikation (manuell auf HA-System testen):**
```bash
# Ingress testen:
# 1. Add-on starten
# 2. "OPEN WEB UI" Button klicken
# 3. Gateway UI sollte ohne Port-Angabe laden

# Panel testen:
# 1. HA Sidebar prüfen → Clawdbot-Icon
# 2. Klicken → Gateway öffnet im Ingress

# Notifications testen:
# 1. update_mode: notify setzen
# 2. Neue Version verfügbar machen (oder simulieren)
# 3. HA UI → Notifications prüfen
```

---

### 🟢 GRUPPE 7: PHASE 6 - DOKUMENTATION (Parallel möglich)
**Status:** Kann während Implementierung beginnen, Final nach Tests

| Task | Abhängigkeiten | Blockt |
|------|---------------|--------|
| 32: INSTALLATION.md | Tasks 25, 31 | - |
| 33: CONFIGURATION.md | Tasks 25, 31 | - |
| 34: TROUBLESHOOTING.md | Tasks 25, 31 | - |
| 35: README.md | Tasks 25, 31 | - |
| 36: CHANGELOG.md | Tasks 25, 31 | Task 43 |
| 37: Add-on Docs | Tasks 25, 31 | - |

**Alle Tasks parallel möglich nach Features fertig!**

---

### 🔴 GRUPPE 8: PHASE 7 - TESTING (KRITISCH)
**Status:** Benötigt alle Features (Tasks 25, 31)

| Task | Abhängigkeiten | Blockt |
|------|---------------|--------|
| 38: Fresh Install | Tasks 25, 31 | - |
| 39: Upgrade Test | Tasks 25, 31 | - |
| 40: Update-Modi Test | Tasks 25, 31 | - |
| 41: Snapshot Test | Tasks 25, 31 | - |
| 42: Rollback Test | Tasks 25, 31 | - |

**Alle Tests parallel möglich!**

---

### 🎯 GRUPPE 9: RELEASE
**Status:** Benötigt alle Tests (Tasks 38-42)

| Task | Abhängigkeiten | Blockt |
|------|---------------|--------|
| 43: Version 1.0.0 setzen | Tasks 36, 38-42 | Task 44 |
| 44: Git Tag erstellen | Task 43 | Task 45 |
| 45: GitHub Release | Task 44 | - |

**Streng sequenziell!**

---

## Kritischer Pfad (Longest Path)

```
Task 5 (Bun-Fix)
  → Task 8 (Multi-Arch Test)
  → Task 12 (Storage Test)
  → Task 20 (Update-System Test)
  → Task 25 (Snapshot Test)
  → Task 42 (Rollback Test)
  → Task 45 (Release)
```

**Geschätzte Dauer kritischer Pfad:** ~18-24 Tage

---

## Optimale Parallelisierung

### Woche 1
**Parallel:**
- Gruppe 1 (Repo Setup) - 1 Tag
- Gruppe 2 (Dockerfile) - 2-3 Tage

**Ende Woche 1:** Funktionierender Multi-Arch Build

### Woche 2
**Sequenziell:**
- Gruppe 3 (Storage) - 3-4 Tage

**Ende Woche 2:** Neue Storage-Struktur funktioniert

### Woche 3
**Sequenziell:**
- Gruppe 4 (Update-System) - 5-7 Tage

**Parallel beginnen:**
- Gruppe 7 (Dokumentation) - ongoing

**Ende Woche 3:** Update-System funktioniert

### Woche 4
**Parallel:**
- Gruppe 5 (Snapshots) - 2-3 Tage
- Gruppe 6 (HA Integration) - 2-3 Tage
- Gruppe 7 (Dokumentation) - fortsetzen

**Ende Woche 4:** Alle Features fertig

### Woche 5
**Sequenziell:**
- Gruppe 8 (Testing) - 3-5 Tage
- Gruppe 9 (Release) - 1 Tag

**Ende Woche 5:** Release v1.0.0! 🎉

---

## Blockierende Dependencies (Achtung!)

### ⛔ ABSOLUTE BLOCKER:
1. **Task 5 (Bun-Fix)** - Ohne funktionierende Builds: GAR NICHTS geht!
2. **Task 8 (Multi-Arch Test)** - Muss vor Storage-Tests funktionieren
3. **Task 12 (Storage Test)** - Blockt Update-System & Snapshots
4. **Task 20 (Update-System Test)** - Blockt Snapshots & HA Integration

### ⚠️ WICHTIGE DEPENDENCIES:
- Task 19 (Update-Logic) benötigt Tasks 13-18 (alle Update-Funktionen)
- Task 30 (Notifications) benötigt Task 19 (Update-Logic muss existieren)
- Task 25 (Snapshot Test) benötigt Task 20 (Update-System muss fertig sein)

### ✅ PARALLELE MÖGLICHKEITEN:
- Gruppe 5 & 6 können parallel laufen (ab Task 20)
- Gruppe 7 kann während Implementierung beginnen
- Gruppe 8 (alle Tests) können parallel laufen

---

## Task-Status Tracking

### Wie arbeiten wir die Tasks ab?

1. **Sequenziell für kritischen Pfad:**
   - Tasks 5 → 8 → 12 → 20 → 25 müssen der Reihe nach

2. **Parallel wo möglich:**
   - Gruppe 1: Alle 3 Tasks parallel
   - Gruppe 4: Tasks 13-14 parallel starten
   - Gruppe 5 & 6: Komplett parallel
   - Gruppe 7: Während Implementierung
   - Gruppe 8: Alle Tests parallel

3. **Validation Points:**
   - Nach Task 8: Multi-Arch Builds funktionieren?
   - Nach Task 12: Storage-Migration funktioniert?
   - Nach Task 20: Updates sicher?
   - Nach Task 25: Snapshots funktionieren?
   - Nach Gruppe 8: Alle Tests grün?

---

## Nächste Schritte

### Heute:
- ✅ Task 1: Plan finalisiert
- ✅ Tasks 2-4: Repo Setup (ABGESCHLOSSEN)
- ✅ Tasks 5-8: Dockerfile PHASE 1 (ABGESCHLOSSEN)
- ✅ Tasks 9-12: Storage PHASE 2 (ABGESCHLOSSEN)
- ✅ Tasks 13-20: Update-System PHASE 3 (ABGESCHLOSSEN)
- ✅ Tasks 21-25: Snapshots PHASE 4 (ABGESCHLOSSEN)
- ✅ Tasks 26-31: HA Integration PHASE 5 (ABGESCHLOSSEN)
- ⏭️ Tasks 32-37: Dokumentation PHASE 6 (NÄCHSTE GRUPPE)

### Diese Woche:
- ✅ PHASE 1-5 komplett (alle Kern-Features!)
- Tasks 32-37: PHASE 6 Dokumentation

### Nächste 2 Wochen:
- Gruppe 7: Dokumentation
- Gruppen 8-9: Testing & Release

### Wochen 4-5:
- Final Testing
- Release v1.0.0! 🎉

---

**Bereit zum Start? Los geht's mit Tasks 2-4 (Repo Setup)! 🚀**
