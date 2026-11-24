#!/usr/bin/env bash
# Nomad2 – eigenes Offline-Wissen auf Deutsch (Wikis + Videos)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

[ -f .env ] || cp .env.example .env
set -a; . ./.env; set +a
DATEN=${DATEN:-./daten}
ZIM="$DATEN/zim"
VID="$DATEN/videos"
KATALOG=inhalte/katalog.txt
QUELLEN=inhalte/videos.txt
SPIEGEL=https://download.kiwix.org/zim
KIWIX_IMAGE=ghcr.io/kiwix/kiwix-tools:latest

rot()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
info() { printf '\033[32m==>\033[0m %s\n' "$*"; }
ende() { rot "Fehler: $*"; exit 1; }
braucht() { command -v "$1" >/dev/null || ende "'$1' fehlt. Installiere es mit: sudo apt install $2"; }

ordner() { mkdir -p "$ZIM" "$VID"; }

# Katalogzeile zu einem Namen: gibt "ordner|präfix|größe|beschreibung" aus
eintrag() {
  awk -F'|' -v n="$1" '!/^[ \t]*#/ && NF>=5 { for(i=1;i<=NF;i++) gsub(/^[ \t]+|[ \t]+$/,"",$i);
    if ($1==n) { print $2"|"$3"|"$4"|"$5; f=1; exit } } END { exit !f }' "$KATALOG"
}

# Neueste Datei zu einem Präfix auf dem Server ermitteln
neueste() { # ordner präfix
  local p; p=$(printf '%s' "$2" | sed 's/[.[\*^$]/\\&/g')
  curl -fsSL --retry 3 "$SPIEGEL/$1/" \
    | grep -o "href=\"${p}_[0-9]\{4\}-[0-9]\{2\}\.zim\"" | sed 's/^href="//; s/"$//' | sort | tail -n 1
}

lokal() { # präfix -> vorhandene Dateien (eine pro Zeile)
  find "$ZIM" -maxdepth 1 -type f -name "$1_[0-9][0-9][0-9][0-9]-[0-9][0-9].zim" 2>/dev/null | sort
}

# library.xml aus allen vorhandenen ZIM-Dateien neu aufbauen
bibliothek() {
  ordner
  docker run --rm --user "$(id -u):$(id -g)" -v "$(readlink -f "$ZIM"):/data" --entrypoint sh "$KIWIX_IMAGE" -c '
    rm -f /data/library.neu
    for f in /data/*.zim; do [ -e "$f" ] && kiwix-manage /data/library.neu add "$f"; done
    [ -e /data/library.neu ] || printf "%s\n" "<?xml version=\"1.0\" encoding=\"UTF-8\"?><library version=\"20110515\"></library>" > /data/library.neu
    mv /data/library.neu /data/library.xml'
}

# Prüft, ob die Datei (abzüglich eines schon geladenen Teils) noch auf die Platte passt
platz_reicht() { # url teildatei
  local gross frei teil=0
  gross=$(curl -fsSIL "$1" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:" { n=$2 } END { print n+0 }')
  [ "${gross:-0}" -gt 0 ] || return 0   # Größe unbekannt: nicht blockieren
  [ -f "$2" ] && teil=$(stat -c %s "$2")
  frei=$(df --output=avail -B1 "$ZIM" | tail -n 1)
  [ $((gross - teil + 1073741824)) -le "$frei" ]   # 1 GB Reserve
}

# Speicherort für alle Inhalte ändern (z. B. externe Platte)
speicher() {
  [ $# -eq 1 ] || { echo "Aktueller Speicherort: $(readlink -f "$DATEN")"; echo "Ändern mit: ./nomad speicher <ordner>"; return; }
  local neu; mkdir -p "$1" || ende "Ordner $1 kann nicht angelegt werden."
  neu=$(readlink -f "$1"); [ -w "$neu" ] || ende "In $neu darf nicht geschrieben werden."
  if grep -q '^DATEN=' .env; then sed -i "s|^DATEN=.*|DATEN=$neu|" .env; else echo "DATEN=$neu" >> .env; fi
  info "Speicherort ist jetzt $neu"
  echo "Vorhandene Inhalte ziehst du so um:  ./nomad stop && mv $(readlink -f "$DATEN")/* $neu/ && ./nomad start"
}

wiki_liste() {
  printf '%-16s %-8s %-12s %s\n' NAME GRÖSSE STATUS BESCHREIBUNG
  grep -v '^[[:space:]]*#' "$KATALOG" | while IFS='|' read -r n _ p g b; do
    n=$(echo $n); p=$(echo $p); [ -n "$n" ] || continue
    s="-"; [ -n "$(lokal "$p")" ] && s="installiert"
    printf '%-16s %-8s %-12s %s\n' "$n" "$(echo $g)" "$s" "$(echo $b)"
  done
  echo; echo "Laden mit:  ./nomad wiki laden <name> [<name> ...]"
}

wiki_laden() {
  [ $# -gt 0 ] || ende "Welche Pakete? Siehe: ./nomad wiki liste"
  braucht curl curl; braucht wget wget; ordner
  local n e o p datei
  for n in "$@"; do
    e=$(eintrag "$n") || { rot "Unbekanntes Paket: $n"; continue; }
    o=${e%%|*}; p=$(echo "$e" | cut -d'|' -f2)
    datei=$(neueste "$o" "$p") || true
    [ -n "$datei" ] || { rot "$n: keine Datei auf dem Server gefunden ($o/$p)"; continue; }
    if [ -f "$ZIM/$datei" ]; then info "$n ist aktuell ($datei)"; continue; fi
    platz_reicht "$SPIEGEL/$o/$datei" "$ZIM/$datei.teil" || { rot "$n: zu wenig freier Speicher in $ZIM – übersprungen. Anderen Speicherort wählen: ./nomad speicher <ordner>"; continue; }
    info "Lade $n: $datei ($(echo "$e" | cut -d'|' -f3)) – Abbruch mit Strg+C, später einfach erneut starten"
    wget -c --tries=20 --show-progress -q -O "$ZIM/$datei.teil" "$SPIEGEL/$o/$datei"
    mv "$ZIM/$datei.teil" "$ZIM/$datei"
    # ältere Ausgaben desselben Pakets entfernen
    lokal "$p" | { grep -vF "/$datei" || true; } | xargs -r rm -f
  done
  bibliothek
  info "Fertig. Wikis: http://localhost:${PORT_WIKI:-8881}"
}

wiki_aktualisieren() {
  local namen=()
  while IFS='|' read -r n _ p _; do
    n=$(echo $n); p=$(echo $p)
    [ -n "$(lokal "$p")" ] && namen+=("$n")
  done < <(grep -v '^[[:space:]]*#' "$KATALOG")
  [ ${#namen[@]} -gt 0 ] || ende "Es ist noch nichts installiert."
  wiki_laden "${namen[@]}"
}

wiki_entfernen() {
  [ $# -gt 0 ] || ende "Welches Paket?"
  local n e p
  for n in "$@"; do
    e=$(eintrag "$n") || { rot "Unbekanntes Paket: $n"; continue; }
    p=$(echo "$e" | cut -d'|' -f2)
    lokal "$p" | xargs -r rm -fv
  done
  bibliothek
}

ytdlp() {
  mkdir -p bin
  if [ ! -x bin/yt-dlp ]; then
    info "Lade yt-dlp herunter"
    curl -fL --retry 3 -o bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux
    chmod +x bin/yt-dlp
  else
    bin/yt-dlp -U >/dev/null 2>&1 || true
  fi
  # YouTube braucht für alle Formate eine JavaScript-Laufzeit (deno); ohne sie geht es nur eingeschränkt.
  if [ ! -x bin/deno ] && ! command -v deno >/dev/null; then
    info "Lade deno herunter (Hilfsprogramm für YouTube)"
    if curl -fL --retry 3 -o bin/deno.zip https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip \
       && python3 -m zipfile -e bin/deno.zip bin/ && chmod +x bin/deno; then rm -f bin/deno.zip
    else rm -f bin/deno.zip; rot "deno konnte nicht geladen werden – es geht ohne weiter, evtl. mit Einschränkungen."; fi
  fi
}

# Liest inhalte/videos.txt und ruft für jede Quelle "$1" auf: laden | vorschau
videos_durchgehen() {
  local modus=$1 h=${VIDEO_HOEHE:-720} zeile thema="" anzahl quelle ordner ok=0
  local -a extra
  while IFS= read -r zeile || [ -n "$zeile" ]; do
    zeile=$(printf '%s' "$zeile" | sed 's/\r$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    case "$zeile" in
      ''|'#'*) continue ;;
      '['*']') thema=${zeile#[}; thema=${thema%]}; thema=${thema//\//-}; continue ;;
    esac
    anzahl=""
    if [[ $zeile =~ ^(.*[^[:space:]])[[:space:]]+([0-9]+)$ ]]; then zeile=${BASH_REMATCH[1]}; anzahl=${BASH_REMATCH[2]}; fi
    case "$zeile" in
      http://*|https://*) quelle=$zeile; extra=(--playlist-end "${anzahl:-25}") ;;
      *) quelle="ytsearch${anzahl:-5}:$zeile"; extra=() ;;
    esac
    ordner=${thema//%/%%}; ordner=${ordner:-%(channel,uploader|Sonstiges)s}
    ok=1
    if [ "$modus" = vorschau ]; then
      printf '\n\033[32m[%s]\033[0m %s\n' "${thema:-ohne Thema}" "$zeile"
      PATH="$PWD/bin:$PATH" bin/yt-dlp --ignore-errors --no-warnings --flat-playlist "${extra[@]}" \
        --print "   %(title).90s  (%(channel,uploader|?)s, %(duration_string|?)s)" "$quelle" </dev/null || true
      continue
    fi
    info "[${thema:-ohne Thema}] $zeile"
    PATH="$PWD/bin:$PATH" bin/yt-dlp --ignore-errors --no-overwrites --no-warnings \
      --download-archive "$VID/.archiv.txt" "${extra[@]}" \
      --match-filter "!is_live & duration>=120 & duration<=7200" \
      --sleep-requests 1 --sleep-interval 2 --max-sleep-interval 6 \
      -S "res:$h,vcodec:h264,acodec:m4a" --merge-output-format mp4 \
      --embed-metadata --write-thumbnail --convert-thumbnails jpg \
      -o "$VID/$ordner/%(upload_date>%Y-%m-%d,release_date>%Y-%m-%d|)s %(title).100B ~ %(channel,uploader|Unbekannt).40B [%(id)s].%(ext)s" \
      "$quelle" </dev/null || rot "Nicht alles zu „$zeile“ konnte geladen werden."
  done < "$QUELLEN"
  [ $ok = 1 ] || ende "Keine Quellen eingetragen. Trage Themen oder Adressen in $QUELLEN ein."
}

videos_laden() {
  braucht curl curl; braucht ffmpeg ffmpeg; ordner; ytdlp
  videos_durchgehen laden
  info "Fertig. Videos: http://localhost:${PORT_START:-8880}/videos"
  du -sh "$VID" 2>/dev/null || true
}

videos_vorschau() { braucht curl curl; ordner; ytdlp; videos_durchgehen vorschau; }

status() {
  docker compose ps 2>/dev/null || true
  echo
  echo "Startseite: http://localhost:${PORT_START:-8880}"
  echo "Wikis:      http://localhost:${PORT_WIKI:-8881}"
  echo "Videos:     http://localhost:${PORT_START:-8880}/videos"
  echo
  [ -d "$DATEN" ] && du -sh "$ZIM" "$VID" 2>/dev/null
  df -h "$DATEN" 2>/dev/null | awk 'NR==2 { print "Frei auf der Platte: " $4 }'
}

hilfe() { cat <<'H'
Nomad2 – Offline-Wissen auf Deutsch

  ./nomad start                    Dienste starten (auch nach jedem Neustart automatisch)
  ./nomad stop                     Dienste stoppen
  ./nomad status                   Adressen, laufende Dienste, Speicherplatz

  ./nomad wiki liste               verfügbare deutsche Wiki-Pakete
  ./nomad wiki laden <name> ...    Pakete herunterladen (fortsetzbar)
  ./nomad wiki aktualisieren       installierte Pakete auf die neueste Ausgabe bringen
  ./nomad wiki entfernen <name>    Paket löschen

  ./nomad videos vorschau          zeigt, welche Videos gefunden würden (lädt nichts)
  ./nomad videos laden             Videos aus inhalte/videos.txt herunterladen

  ./nomad speicher [<ordner>]      Speicherort anzeigen oder ändern (z. B. externe Platte)
H
}

case "${1:-hilfe}" in
  start)  braucht docker docker.io; ordner; [ -f "$ZIM/library.xml" ] || bibliothek
          docker compose up -d; status ;;
  stop)   docker compose down ;;
  status) status ;;
  speicher) shift; speicher "$@" ;;
  wiki)   case "${2:-liste}" in
            liste) wiki_liste ;;
            laden) shift 2; wiki_laden "$@" ;;
            aktualisieren) wiki_aktualisieren ;;
            entfernen) shift 2; wiki_entfernen "$@" ;;
            *) hilfe ;;
          esac ;;
  videos) case "${2:-laden}" in laden) videos_laden ;; vorschau) videos_vorschau ;; *) hilfe ;; esac ;;
  *)      hilfe ;;
esac
