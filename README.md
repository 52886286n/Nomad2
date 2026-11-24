# Nomad2

Ein eigenes, schlankes „Project N.O.M.A.D.“ auf Deutsch: deutsche Wikis und deutsche
Videos, komplett offline nutzbar – auf dem Laptop selbst und für alle Geräte im selben WLAN.

Alles ist auf Deutsch, es gibt keine Anmeldung, keinen Einrichtungsassistenten und keine KI –
nur zwei kleine Dienste (nginx und Kiwix), die auch auf schwacher Hardware laufen.

| Dienst     | Adresse                        |
|------------|--------------------------------|
| Startseite | http://localhost:8880          |
| Videos     | http://localhost:8880/videos   |
| Wikis      | http://localhost:8881 (Kiwix, Oberfläche folgt der Browsersprache) |

Die Ports überschneiden sich nicht mit Project N.O.M.A.D., beides kann nebeneinander laufen.

## Einrichten (Debian/Ubuntu/Mint)

**Docker ist schon installiert** (z. B. weil Project N.O.M.A.D. läuft)? Dann auf keinen Fall
`docker.io` nachinstallieren – das verdrängt das vorhandene Docker. Es fehlen nur die Hilfsprogramme:

```bash
sudo apt install curl wget ffmpeg git
```

**Noch kein Docker vorhanden** (`docker --version` meldet „nicht gefunden“):

```bash
sudo apt install docker.io docker-compose-v2 curl wget ffmpeg git
```

Danach in beiden Fällen:

```bash
sudo usermod -aG docker $USER
```

Einmal ab- und wieder anmelden, dann:

```bash
git clone https://github.com/52886286n/Nomad2.git
cd Nomad2
./nomad start
```

## Deutsche Wikis

```bash
./nomad wiki liste                          # was gibt es?
./nomad wiki laden klexikon wikipedia-top   # kleiner Start (ca. 4,3 GB)
./nomad wiki laden wikipedia                # komplette Wikipedia mit Bildern (45 GB)
./nomad wiki aktualisieren                  # später: neueste Ausgaben holen
```

Downloads lassen sich jederzeit abbrechen und mit demselben Befehl fortsetzen. Weitere
Pakete trägst du als Zeile in `inhalte/katalog.txt` ein.

## Deutsche Videos

1. Adressen in `inhalte/videos.txt` eintragen (YouTube-Kanäle/-Playlists, ARD-/ZDF-/arte-Mediathek).
2. `./nomad videos laden` – lädt nur, was noch fehlt, sortiert nach Kanal.
3. http://localhost:8880/videos öffnen: Suche, Kanalfilter und Player direkt im Browser.

Eigene Videodateien (MP4) kannst du einfach in einen Unterordner von `daten/videos/` legen,
sie erscheinen sofort auf der Videoseite.

Bitte nur Inhalte laden, die du privat offline speichern darfst.

## Speicherort und Einstellungen

```bash
./nomad speicher                       # zeigt, wo die Inhalte liegen
./nomad speicher /media/platte/nomad2  # z. B. auf eine externe Platte wechseln
./nomad status                         # Adressen und freier Speicherplatz
```

Vor jedem Wiki-Download wird geprüft, ob der Platz reicht. Ports und Videoqualität stehen in
`.env` (wird beim ersten Start aus `.env.example` angelegt). `./nomad stop` beendet alles.
