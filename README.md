# Backup-Skript mit Pushover-Benachrichtigungen

Dieses Bash-Skript dient zur Sicherung von Verzeichnissen auf einem Remote-Backup-Server. Es bietet:
- **Automatische Konfiguration** bei der ersten Ausführung.
- **Einfache Verwaltung** der Backup-Einstellungen über einen interaktiven Konfigurationsdialog.
- **Automatischer Skriptaufruf** durch das Anlegen eines täglichen Cronjobs mit Auswahlmöglichkeit der Uhrzeit.
- **Benachrichtigungen** über den Status des Backups mit Pushover.

---

## **Funktionen**
1. **Backup von Verzeichnissen**:
   - Sichert ausgewählte Verzeichnisse auf einen Remote-Server via `rsync`.
2. **Fehlerbenachrichtigung**:
   - Benachrichtigt per Pushover über Erfolge und Fehler während des Backups.
3. **First-Start-Wizard**:
   - Führt bei der ersten Ausführung eine interaktive Einrichtung durch.
4. **Konfigurationsdialog**:
   - Ermöglicht das Hinzufügen, Ändern oder Löschen von Verzeichnissen und das Bearbeiten des Backup-Servers.
5. **Protokollierung**:
   - Erkennt und meldet detaillierte Fehler bei fehlgeschlagenen Backups.

---

## **Systemanforderungen**
- **Bash** (Version 4.0 oder höher)
- **rsync**: Für das Kopieren von Dateien und Verzeichnissen.
- **curl**: Für das Senden von Benachrichtigungen über Pushover.
- **Pushover-Konto**: Zum Senden von Benachrichtigungen.

---

## **Installation**
1. Klone das Repository oder lade das Skript herunter:
   git clone https://github.com/chrisse1/backup_script.git
2. cd backup-script
3. chmod +x backup.sh
4. ./backup.sh
5. Folge den Anweisungen zur Konfiguration
