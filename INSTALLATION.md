# Clawdbot HA Add-on – Installationsanleitung

Komplette Schritt-für-Schritt-Anleitung zur Installation des **Clawdbot Gateway** Home-Assistant Add-ons.

---

## Voraussetzungen

Bevor du das Clawdbot Add-on installierst, stelle Folgendes sicher:

- **Home Assistant OS** oder **Home Assistant Supervised**
- **Mindestens 2 GB freier Speicherplatz** (Builds & Cache)
- **Optional:** SSH-Zugriff (nur wenn du Debug/CLI im Container brauchst)
- **Anthropic API Key** (erhältst du über [console.anthropic.com](https://console.anthropic.com))

### Unterstützte Architekturen

- `amd64` (Intel/AMD 64-bit)
- `aarch64` (ARM 64-bit, z. B. Raspberry Pi 4/5)
- `armv7` (ARM 32-bit, z. B. Raspberry Pi 3)

---

## Installation

### Schritt 1: Repository in Home Assistant hinzufügen

1. Öffne deine **Home Assistant UI**
2. Gehe zu **Einstellungen → Add-ons → Add-on Store**
3. Klicke oben rechts auf **⋮** (drei Punkte)
4. Wähle **Repositories**
5. Füge diese Repository-URL hinzu:
   ```
   https://github.com/Al3xand3r1987/clawdbot-ha
   ```
6. Klicke **Hinzufügen**

Das Repository sollte jetzt im Add-on Store erscheinen.

---

### Schritt 2: Clawdbot Gateway Add-on installieren

1. Scrolle im **Add-on Store** nach unten und suche **„Clawdbot Gateway“**
2. Öffne das Add-on
3. Klicke **Installieren**
4. Warte, bis die Installation abgeschlossen ist (typisch 5–10 Minuten)
   - Der initiale Build beinhaltet u. a.:
     - Node.js, Bun, pnpm, TypeScript
     - GitHub CLI, gog CLI
     - Clawdbot Quellcode und Abhängigkeiten

---

### Schritt 3: Add-on konfigurieren

#### Basis-Konfiguration

1. Nach der Installation: öffne den Tab **Konfiguration**
2. Setze mindestens diese Option (empfohlen):

```yaml
update_mode: stable
```

**Wichtige Option:**
- `update_mode`: Update-Verhalten (siehe [CONFIGURATION.md](CONFIGURATION.md))

#### Optionale Konfiguration

```yaml
easy_setup_ui: false  # Optional: Setup-Seite im Ingress unter /__setup/ (OAuth/API Keys ohne SSH)
pinned_version: ""  # Optional: auf eine bestimmte Version pinnen
max_cached_versions: 2  # Wie viele Versionen im Cache behalten
auto_cleanup_versions: true  # Alte Versionen automatisch entfernen
ssh_port: 2222  # Optional: SSH-Port (nur relevant wenn SSH aktiv)
ssh_authorized_keys: "ssh-ed25519 AAAA... user@host"  # Optional: SSH aktivieren (nur Public Key, kein Passwort)
```

Eine vollständige Options-Liste findest du in [CONFIGURATION.md](CONFIGURATION.md).

---

### Schritt 4: Add-on starten

1. Öffne den Tab **Info**
2. Aktiviere **Start beim Booten** (empfohlen)
3. Aktiviere **Watchdog** (optional, für automatischen Neustart)
4. Klicke **Start**

**Beim ersten Start passiert Folgendes:**
- Klonen/Initialisieren der Clawdbot-Quelle
- Installation der Abhängigkeiten
- Build von Gateway und UI
- Kann beim ersten Start **10–15 Minuten** dauern (je nach Hardware)

**Logs beobachten:**
- Öffne den Tab **Log**
- Achte u. a. auf Hinweise wie `using version: ...` oder `setup proxy started ...`
- Wichtig: Der Gateway-Port ist standardmäßig `18789` (siehe Option `port`)

---

### Schritt 5: Clawdbot öffnen

Es gibt drei Wege, Clawdbot zu öffnen:

#### Option A: Web UI (Ingress) – empfohlen

1. Öffne den Tab **Info** des Add-ons
2. Klicke **„OPEN WEB UI“**
3. Die Clawdbot Oberfläche öffnet sich innerhalb von Home Assistant (Ingress)

**Optionales Setup (ohne SSH):** Wenn du `easy_setup_ui: true` setzt, kannst du im Ingress zusätzlich `/__setup/` öffnen (OAuth/API Keys).

**ODER**

1. Schau in deine **Home Assistant Sidebar**
2. Suche nach dem **Clawdbot Icon** (Roboter)
3. Klicke darauf, um die Oberfläche zu öffnen

#### Option B: Direkter Zugriff über Port

Direkter Zugriff:
```
http://DEINE-HA-IP:18789
```

#### Option C: Konfiguration per SSH

Für Konfiguration per Kommandozeile:

```bash
# Von deinem Computer
ssh -p 2222 root@DEINE-HA-IP

# Im Container
cd /config/clawdbot/data
nano clawdbot.json
```

**Hinweis:** SSH ist optional und läuft nur, wenn `ssh_authorized_keys` in der Add-on Konfiguration gesetzt ist.

---

### Schritt 6: Anthropic API Key konfigurieren

#### Über Setup UI (Ingress, ohne SSH) – empfohlen

1. Setze in der Add-on Konfiguration `easy_setup_ui: true` (optional, aber fürs erste Setup sehr praktisch)
2. Öffne die Add-on Web UI (Ingress)
3. Öffne `/__setup/`
4. Füge deinen **Anthropic API Key** ein und klicke **Speichern**

**Hinweis:** Die Setup-Seite schreibt Keys nach `/config/clawdbot/data/state/.env` (nicht in `clawdbot.json`).

#### Über Web UI (am einfachsten)

1. Öffne die Clawdbot Web UI (siehe Schritt 5)
2. Gehe zu **Settings** (Einstellungen)
3. Trage deinen **Anthropic API Key** ein
4. Klicke **Save** (Speichern)

#### Über SSH

```bash
ssh -p 2222 root@DEINE-HA-IP

# Konfiguration bearbeiten
cd /config/clawdbot/data
nano clawdbot.json
```

API Key eintragen (Beispiel mit Platzhalter):
```json
{
  "anthropic_api_key": "sk-ant-api03-your-key-here",
  ...
}
```

Speichern und das Add-on neu starten.

---

### Schritt 7: Installation prüfen

1. **Logs prüfen:**
   - Am einfachsten: Im Add-on UI den Tab **Log** öffnen.
   - Per CLI (falls du Zugriff auf die HA CLI hast):
     1. Add-ons auflisten und den exakten Slug/Identifier finden:
        ```bash
        ha addons list
        ```
     2. Dann Logs anzeigen:
        ```bash
        ha addons logs <ADDON_SLUG>
        ```

   **Typische Hinweise in den Logs:**
   - `using version: vYYYY.M.DD` (oder ähnlich)
   - `setup proxy started ... bind=127.0.0.1:8099 ...`
   - Optional (wenn SSH aktiviert): `sshd listening on ...`

2. **Web UI testen:**
   - Klicke **„OPEN WEB UI“**
   - Du solltest die Clawdbot Oberfläche sehen
   - Teste eine einfache Nachricht, z. B.: „Hallo, Claude!“

3. **Dateistruktur prüfen:**
   ```bash
   ssh -p 2222 root@DEINE-HA-IP
   ls -la /config/clawdbot/
   ```

   Du solltest ungefähr Folgendes sehen:
   ```
   drwxr-xr-x cache/
   drwxr-xr-x data/
   drwxr-xr-x .meta/
   drwxr-xr-x source/
   ```

---

## Checkliste: Erstes Setup

Nach der Installation solltest du Folgendes erledigen:

- [ ] Add-on installiert und erfolgreich gestartet
- [ ] Web UI über **„OPEN WEB UI“** erreichbar
- [ ] Anthropic API Key konfiguriert
- [ ] Testnachricht gesendet und Antwort erhalten
- [ ] (Optional) SSH-Zugriff funktioniert (nur wenn aktiviert)
- [ ] Snapshot/Backup erstellt (empfohlen)

---

## Update-Strategie

Das Add-on enthält ein **automatisches Update-System** mit folgenden Modi:

- **`stable` (Standard)**: automatische Updates nur auf Stable-Releases
- **`notify`**: Hinweis bei Updates (manuelle Freigabe)
- **`latest`**: inkl. Pre-Releases (alpha, beta, rc)
- **`disabled`**: keine automatischen Updates

Konfiguriere das im Add-on Tab **Konfiguration** über `update_mode`.

Mehr Details: [CONFIGURATION.md](CONFIGURATION.md#update-modes).

---

## Nächste Schritte

Nach erfolgreicher Installation:

1. **Telegram/WhatsApp konfigurieren** (optional)
   - Siehe [CONFIGURATION.md](CONFIGURATION.md#messaging-integrations)

2. **Ersten Snapshot erstellen**
   - Einstellungen → System → Backups → Backup erstellen
   - Damit du im Notfall wiederherstellen kannst

3. **Skills erkunden**
   - Nutze die Web UI, um verfügbare Skills zu entdecken
   - Skills liegen unter `/config/clawdbot/data/workspace/`

4. **Community**
   - Issues melden: [GitHub Issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)
   - Beitragen: siehe [CLAUDE.md](CLAUDE.md)

---

## Migration von v0.2.14

Wenn du von einer älteren Version (v0.2.14) upgradest, migriert das Add-on deine Daten beim ersten Start **automatisch**:

- Alter Pfad: `/config/clawdbot/.clawdbot/`
- Neuer Pfad: `/config/clawdbot/data/`

**Deine Daten bleiben erhalten:**
- `clawdbot.json` Konfiguration
- State-Daten
- Workspace und Skills

Keine manuellen Schritte erforderlich!

---

## Fehlersuche

Wenn du bei der Installation Probleme hast, siehe [TROUBLESHOOTING.md](TROUBLESHOOTING.md) für:

- Build-Fehler
- SSH-Verbindungsprobleme
- API-Key-Probleme
- Update-Fehler
- Snapshot-Restore-Probleme

---

## Unterstützung

Brauchst du Hilfe?

- **Dokumentation**: [README.md](README.md), [CONFIGURATION.md](CONFIGURATION.md)
- **Issues**: [GitHub Issues](https://github.com/Al3xand3r1987/clawdbot-ha/issues)
- **Community**: Home Assistant Community Forums

---

**Installation abgeschlossen! Viel Erfolg mit Clawdbot in Home Assistant!**
