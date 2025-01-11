#!/bin/bash

# Verzeichnis des Skripts ermitteln und setzen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

CONFIG_FILE="backup.conf"

# First-Start-Wizard
first_start_wizard() {
    echo "Willkommen zum First-Start-Wizard für local2rsync!"
    echo "Bitte geben Sie die erforderlichen Informationen ein."

    # Titel des Backups
    read -rp "Titel des Backups (Beispiel: Server, Desktop... Standard: Server): " BACKUP_TITLE
    BACKUP_TITLE=${BACKUP_TITLE:-"Server"}

    # Pushover-Token
    read -rp "Pushover-Token: " PUSHOVER_TOKEN
    read -rp "Pushover-User-ID: " PUSHOVER_USER

    # Backup-Server angeben und Verfügbarkeit prüfen
    while true; do
        read -rp "Backup-Server (z. B. rsyncserver): " BACKUP_SERVER
        if [[ -z $BACKUP_SERVER ]]; then
            echo "Backup-Server darf nicht leer sein."
            continue
        fi

        echo "Prüfe Verfügbarkeit von '$BACKUP_SERVER' ..."
        if rsync "$BACKUP_SERVER::" >/dev/null 2>&1; then
            echo "Server '$BACKUP_SERVER' ist erreichbar."
            break
        else
            echo "Fehler: Der Server '$BACKUP_SERVER' ist nicht erreichbar. Bitte prüfen Sie die Adresse."
        fi
    done

    # Verfügbare rsync-Module auflisten
    echo "Hole verfügbare rsync-Module von '$BACKUP_SERVER' ..."
    RSYNC_MODULES=$(rsync "$BACKUP_SERVER::" 2>/dev/null | awk '{print $1}')
    if [[ -z $RSYNC_MODULES ]]; then
        echo "Keine rsync-Module auf dem Server gefunden. Bitte prüfen Sie die Konfiguration."
        exit 1
    fi

    echo "Verfügbare rsync-Module:"
    echo "$RSYNC_MODULES"

    # Modul auswählen
    while true; do
        read -rp "Wählen Sie ein rsync-Modul aus (z. B. Backup): " RSYNC_MODULE
        if echo "$RSYNC_MODULES" | grep -qw "$RSYNC_MODULE"; then
            BACKUP_SERVER="$BACKUP_SERVER::$RSYNC_MODULE"
            echo "Modul '$RSYNC_MODULE' ausgewählt."
            break
        else
            echo "Ungültige Eingabe. Bitte wählen Sie ein gültiges Modul aus."
        fi
    done

    # Backup-Pfade
    echo "Geben Sie die zu sichernden Verzeichnisse an. Format: name:path"
    echo "Beispiel: fhem:/opt/fhem/"
    echo "Leere Eingabe beendet die Eingabe."
    BACKUP_PATHS=()
    while true; do
        read -rp "Backup-Pfad: " entry
        [[ -z $entry ]] && break
        BACKUP_PATHS+=("$entry")
    done

    # Uhrzeit für den Cronjob abfragen
    echo "Zu welcher Uhrzeit soll das Backup täglich ausgeführt werden? (HH:MM, 24-Stunden-Format)"
    while true; do
        read -rp "Uhrzeit: " BACKUP_TIME
        if [[ $BACKUP_TIME =~ ^([01]?[0-9]|2[0-3]):([0-5]?[0-9])$ ]]; then
            CRON_HOUR=${BASH_REMATCH[1]}
            CRON_MINUTE=${BASH_REMATCH[2]}
            break
        else
            echo "Ungültiges Format. Bitte geben Sie die Uhrzeit im Format HH:MM ein."
        fi
    done

    # Konfigurationsdatei erstellen
    echo "Erstelle Konfigurationsdatei '$CONFIG_FILE' ..."
    {
        echo "# Titel des Backups"
        echo "BACKUP_TITLE=\"$BACKUP_TITLE\""
        echo "# Pushover-Konfiguration"
        echo "PUSHOVER_TOKEN=\"$PUSHOVER_TOKEN\""
        echo "PUSHOVER_USER=\"$PUSHOVER_USER\""
        echo
        echo "# Backup-Konfiguration"
        echo "BACKUP_SERVER=\"$BACKUP_SERVER\""
        echo "BACKUP_PATHS=("
        for path in "${BACKUP_PATHS[@]}"; do
            echo "    \"$path\""
        done
        echo ")"
                echo
        echo "# Cronjob-Zeit"
        echo "BACKUP_TIME=\"$BACKUP_TIME\""
    } >"$CONFIG_FILE"

    # Cronjob einrichten
    echo "Richte Cronjob ein ..."
    setup_cronjob "$CRON_HOUR" "$CRON_MINUTE"

    echo "Konfiguration abgeschlossen. Sie können die Datei '$CONFIG_FILE' bei Bedarf manuell, oder mit ./backup.sh --configure bearbeiten."
    
    # Abfrage: Backup direkt ausführen
    echo "Möchten Sie direkt ein Backup ausführen? (ja/nein)"
    while true; do
        read -rp "Antwort: " response
        case "$response" in
            ja|JA|Ja|j|J)
                echo "Starte Backup ..."
                return 0
                ;;
            nein|NEIN|Ne|n|N)
                echo "Backup wird nicht ausgeführt. Sie können es später manuell starten oder es wird automatisch durch den Cronjob ausgeführt."
                return 1
                ;;
            *)
                echo "Ungültige Eingabe. Bitte antworten Sie mit 'ja' oder 'nein'."
                ;;
        esac
    done
}

# Funktion: Cronjob einrichten
setup_cronjob() {
    local hour=$1
    local minute=$2
    local script_path="$(realpath "$0")"

    # Cronjob hinzufügen
    (crontab -l 2>/dev/null; echo "$minute $hour * * * /bin/bash $script_path >> /var/log/backup_script.log 2>&1") | crontab -
    echo "Cronjob erfolgreich eingerichtet: $hour:$minute Uhr täglich."
}

# Prüfen, ob Konfigurationsdatei existiert
if [[ ! -f $CONFIG_FILE ]]; then
    first_start_wizard
fi

# Konfiguration einlesen
source "$CONFIG_FILE"

errors=0
messages=()
error_details=()

# Überprüfen, ob erforderliche Programme installiert sind
if ! command -v rsync &>/dev/null; then
    echo "Fehler: 'rsync' ist nicht installiert. Bitte installieren und erneut versuchen."
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "Fehler: 'curl' ist nicht installiert. Bitte installieren und erneut versuchen."
    exit 1
fi

# Funktion: Zahlen in Worte konvertieren
number_to_words() {
    case $1 in
        0) echo "null" ;;
        1) echo "einem" ;;
        2) echo "zwei" ;;
        3) echo "drei" ;;
        4) echo "vier" ;;
        5) echo "fünf" ;;
        6) echo "sechs" ;;
        7) echo "sieben" ;;
        8) echo "acht" ;;
        9) echo "neun" ;;
        10) echo "zehn" ;;
        *) echo "$1" ;; # Für größere Zahlen
    esac
}

# Funktion: Singular oder Plural für "Fehler" auswählen
get_error_word() {
    if [[ $1 -eq 1 ]]; then
        echo "Fehler"
    else
        echo "Fehlern"
    fi
}

# Funktion zum Backup
backup() {
    local name=$1
    local path=$2
    local dest="$BACKUP_SERVER/$name/"
    local old_dir="$BACKUP_OLD/${name}_old/"

    # Backup ausführen und Fehlerdetails erfassen
    if rsync -av --delete "$path" "$dest" --backup-dir="$old_dir" >/dev/null 2>&1; then
        messages+=("- Das Datenverzeichnis von $name wurde erfolgreich gesichert!")
    else
        local error_message
        error_message=$(rsync -av --delete "$path" "$dest" --backup-dir="$old_dir" 2>&1)
        messages+=("- Das Datenverzeichnis von $name konnte nicht gesichert werden!")
        error_details+=("Fehler beim Sichern von $name: $error_message")
        errors=$((errors + 1))
    fi
}

# Backups ausführen
for entry in "${BACKUP_PATHS[@]}"; do
    IFS=":" read -r name path <<< "$entry"
    backup "$name" "$path"
done

# Fehler in Worte umwandeln
error_words=$(number_to_words $errors)
error_label=$(get_error_word $errors)

# Nachrichtentitel und Sound festlegen
if [[ $errors -eq 0 ]]; then
    title="$BACKUP_TITLE-Backup erfolgreich beendet"
    sound="cosmic"
else
    title="Das $BACKUP_TITLE-Backup wurde mit $error_words $error_label beendet"
    sound="falling"
fi

# Fehlerdetails an die Nachricht anhängen
if [[ $errors -gt 0 ]]; then
    messages+=("")
    messages+=("Fehlerdetails:")
    messages+=("${error_details[@]}")
fi

# Nachricht senden (Konsolenausgabe unterdrückt)
curl -s \
    --form-string "token=$PUSHOVER_TOKEN" \
    --form-string "user=$PUSHOVER_USER" \
    --form-string "message=$(printf "%s\n" "${messages[@]}")" \
    --form-string "title=$title" \
    --form-string "sound=$sound" \
    https://api.pushover.net/1/messages.json >/dev/null 2>&1

exit $errors
