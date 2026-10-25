# Sanguine Protocol

3D-Action-RPG / LitRPG für Android, gebaut mit Godot 4.7 (Mobile-Renderer), Cel-Shading im Comic-Look.

Jahr 2185, Vanguard-Akademie: Du bist **Kadett-Subjekt 0** – ohne Gen-Anpassungen, gemobbt, kurz vor dem Rauswurf. In den Ruinen des alten Archivs erweckt dein Blut das verbotene **Sanguine-Protokoll**: ein holografisches RPG-System mit unbegrenztem Potenzial – und einer tödlichen Bedingung: **Deine Lebensenergie zehrt von Blut.**

## Was schon drin ist (Kapitel 1 – Erwachen)

- **Story:** Intro → Relikt berühren (Erwachen) → Karkosa-Einbruch im Archiv → Rivale Drax in der Trainingshalle → Karkosa-Nest im Ostflügel → Gespräch mit dem Protokoll.
- **Blut-Hunger-Loop:** Blut-Anzeige leert sich in Echtzeit (END verlangsamt). Bei 0 % Blutmangel: HP-Verlust, weniger Schaden und Tempo.
- **Blut-Essenzen:** Karkosa-Blut (Rüstung + Stärke), Mutanten-Blut (Schattenkraft, kürzere Abklingzeiten), Menschliches Blut (am meisten Blut + EXP, aber **Verdacht** steigt). Bei 100 % Verdacht jagt dich Ausbilder Varek.
- **Kampf:** 3er-Kombo mit Zielhilfe (halten = Dauerangriff), Schatten-Dash mit Unverwundbarkeit, **perfekter Dash** (kurz vor dem Treffer) mit Zeitlupe, Blutsichel, Blutlanze, Eklipse.
- **Gegner:** Karkosa-Späher, Karkosa-Klingen, Mutanten (Säurespucke), Kadetten, Rivale Drax, Ausbilder Varek, Karkosa-Nest. Angriffe werden mit roten Kreisen angekündigt.
- **Progression:** Level-ups mit frei verteilbaren Punkten auf STR / AGI / END / SHD, Skill-Baum mit 9 Skills.
- **Quests:** Hauptquest, 3 tägliche System-Quests (Echtzeit, mit Systemstrafe bei Nichterfüllung), 2 verborgene Quests.
- **Hologramm-UI:** HUD nach GDD (Werte oben links, Quest oben rechts, Joystick unten links, Aktionsknöpfe unten rechts), System-Fenster mit Status, Inventar, Skills und Quests.
- **Welt:** Archivruinen, Neon-Korridor, Trainingshalle, Wartungsgang, Ostflügel, ein verborgenes Gewölbe. Ingame-Uhr (1 Sekunde = 1 Minute).
- Spielstand wird automatisch gespeichert (auch beim Wechsel aus der App). Am Relikt kann man ruhen (HP + Speichern).

## APK bekommen

Bei jedem Push auf `main` baut GitHub Actions automatisch eine APK:
**Actions → „Android-APK bauen“ → letzter Lauf → Artifacts → sanguine-protocol-apk**

Damit Updates ohne Neuinstallation klappen, braucht das Repo zwei Secrets mit einem festen Signierschlüssel:
`KEYSTORE_BASE64` (Keystore als Base64, Alias `sanguine`) und `KEYSTORE_PASSWORD`.
Ohne Secrets wird bei jedem Lauf ein neuer Wegwerf-Schlüssel erzeugt (dann vor dem Update die alte App deinstallieren).

## Steuerung

| Touch | Tastatur (zum Testen am PC) |
|---|---|
| linke Bildschirmhälfte ziehen: laufen | WASD |
| großer Knopf: Angriff (halten = Kombo) | J |
| Doppelpfeil: Schatten-Dash | K / Leertaste |
| roter Kreis: Blutsichel · weitere Skills nach Freischaltung | L, U, I |
| Tropfen: Blut-Essenz trinken | F |
| SYSTEM: Status, Inventar, Skills, Quests | Tab / M |
| Zurück-Taste: System-Fenster | – |

## Aufbau

| Pfad | Inhalt |
|---|---|
| `scripts/autoload/player_stats.gd` | Autoload `PlayerStats`: Werte, Blut-Hunger, Level, Buffs, Inventar, Skill-Baum, Quests, Verdacht, Uhr, Spielstand |
| `scripts/main.gd` | Spielablauf: Titel, Intro, Erwachen, Story-Regie, Spawns, Kamera, Effekte |
| `scripts/player/player.gd` | Spielfigur: Bewegung, Kombo, Dash, Skills, Treffer |
| `scripts/enemies/enemy.gd` | Gegner-KI (Navigation, Telegraph, Kombos, Ansturm, Säure, Nest) |
| `scripts/enemies/creature_models.gd` | Karkosa- und Mutanten-Modelle mit prozeduraler Animation |
| `scripts/world/humanoid.gd` | Menschen-Modell mit prozeduraler Animation |
| `scripts/world/academy.gd` | Level: Räume, Licht, Navigationsnetz |
| `scripts/world/batcher.gd` | fasst Level-Meshes zusammen (weniger Draw-Calls auf dem Handy) |
| `scripts/world/toon.gd` | Materialien und Geometrie-Bausteine |
| `scripts/world/sfx.gd` | prozedurale Soundeffekte |
| `scripts/ui/hud.gd`, `system_window.gd`, `holo_ui.gd` | Hologramm-HUD, System-Fenster, UI-Baukasten |
| `shaders/` | Toon-Shading, Inverted-Hull-Konturen, Hologramme |
| `tests/autotest.tscn` | automatischer Durchlauf von Kapitel 1 mit Prüfungen und Screenshots |

## Lokal testen

```
godot --path . res://tests/autotest.tscn   # SP_FRESH=1, SHOT_DIR=/pfad für Screenshots
```

Schriften: Chakra Petch und IBM Plex Mono (SIL Open Font License, siehe `fonts/`).
