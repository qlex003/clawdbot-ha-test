# Projekt-Instruktionen (Cursor Agent)

## Sprache
- Antworte **immer auf Deutsch** (Dokumentation, Kommentare, Chat-Antworten), außer wenn ein exaktes Zitat/Code-Snippet es erfordert.

## Source of Truth (vor Änderungen prüfen)
- Entwicklungs-Guidelines: `CLAUDE.md`
- Add-on Runtime/Update-Logik: `clawdbot_gateway/run.sh`
- Add-on Metadaten/Options/Schema: `clawdbot_gateway/config.json`
- HA Repository-Metadaten: `repository.json`
- Doku: `README.md`, `INSTALLATION.md`, `CONFIGURATION.md`, `TROUBLESHOOTING.md`

## Arbeitsprinzipien
- **Keine Secrets**: Niemals echte API Keys/Tokens/Passwörter committen oder in Beispiele schreiben.
- **Konventionen**: Conventional Commits verwenden (siehe `CLAUDE.md`).
- **Sicherheit**: Keine destruktiven Git-Aktionen (force push, hard reset, history rewrite), außer explizit beauftragt.
- **Add-on Stabilität**: Update-/Rollback-/Snapshot-Mechanik in `run.sh` nicht „vereinfachen“ oder entfernen; Änderungen nur gezielt und nachvollziehbar.

## Änderungen an Add-on Optionen/Doku
- Wenn `clawdbot_gateway/config.json` (options/schema) geändert wird, muss die Doku konsistent nachgezogen werden.
- Beispiele immer mit Platzhaltern (z. B. `sk-ant-...`, `YOUR-HA-IP`).

