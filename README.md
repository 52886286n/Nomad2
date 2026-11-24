# Nomad2

Ein eigenes, schlankes „Project N.O.M.A.D.“ auf Deutsch: deutsche Wikis und deutsche
Videos, komplett offline nutzbar – auf dem Laptop selbst und für alle Geräte im selben WLAN.

| Dienst     | Adresse                 | Software                    |
|------------|-------------------------|-----------------------------|
| Startseite | http://localhost:8880   | nginx (deutsche Übersicht)  |
| Wikis      | http://localhost:8881   | Kiwix                       |
| Videos     | http://localhost:8096   | Jellyfin                    |

Die Ports überschneiden sich nicht mit Project N.O.M.A.D., beides kann nebeneinander laufen.

## Einrichten (Debian/Ubuntu/Mint)

```bash
sudo apt install docker.io docker-compose-v2 curl wget ffmpeg git
sudo usermod -aG docker $USER      # danach einmal ab- und wieder anmelden
git clone https://github.com/52886286n/Nomad2.git && cd Nomad2
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
3. Beim ersten Öffnen von http://localhost:8096 in Jellyfin: Sprache **Deutsch** wählen,
   Benutzer anlegen und eine Bibliothek vom Typ „Heimvideos und Fotos“ mit dem Ordner
   `/media/videos` hinzufügen.

Bitte nur Inhalte laden, die du privat offline speichern darfst.

## Einstellungen

In `.env` (wird beim ersten Start aus `.env.example` angelegt): Ports, Videoqualität und
`DATEN` – der Speicherort, z. B. eine externe Platte (`DATEN=/media/platte/nomad2`).

`./nomad status` zeigt Adressen und freien Speicherplatz, `./nomad stop` beendet alles.
