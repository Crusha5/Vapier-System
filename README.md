# Sanguine Protocol

Open-World-RPG für Android (Godot 4.7, Compatibility-Renderer), düster-stilisiert. Kamera von hinten oder Ego-Perspektive, jederzeit umschaltbar.

**Veyra** – eine Kolonie, seit zwölf Jahren vom **Schleier** (einem roten Sturm) von der Erde abgeschnitten. Soldat **Kael** hat sich geweigert, das Dorf Morrow niederzubrennen. Kommandant Varek hat ihn erschossen und in den Ruinen der Alten liegen lassen. Dort erweckt ihn **die Erste Nacht** – als Blutgeborenen, mit einem Protokoll im Kopf.

## v0.5 – Echte Figuren, Atmosphäre, Grafikstufen

- **Figuren** aus Quaternius' Universal Base Characters + Modular Character Outfits (CC0): Kael im dunklen Kapuzenmantel, Dorfbewohner als Bauern, Wirtin, Schmied, Banditen mit roten Tüchern, Wacht in Rüstung mit Helm, Krähe im Knochenkragen. Haare, Bärte, Strohhut, Schwerter, Armbrust.
- **Animationen** aus der Universal Animation Library 1+2 (CC0): Gehen, Laufen, Sprinten, Schwertkombos, Treffer, Tod, Sitzen am Feuer, Schlafen, Knien, Weinen, Reden, Feldarbeit, Biss beim Trinken.
- **Atmosphäre:** Wolken, Farbstimmung, Bodennebel bei Nacht und Morgengrauen, Wasser mit Tiefe und Ufer-Schaum.
- **Orte:** Stein-, Holz- und Ziegeltexturen auf Ruine, Palisaden und Turm; neuer runder Wachturm mit Ziegelhaube; Bänke, Fässer, Truhe, Karren, Laternen; Felsen und Ranken an der Ruine.
- **Dichte:** mehr Gras, Büsche, Farne, Blumen und Pilze.
- **Grafikstufen** Niedrig/Mittel/Hoch (Titel und Systemmenü).

## v0.4 – Grafik-Umbau

- Echte Modelle statt Bastelformen: Bäume, Büsche, Farne, Gras, Felsen und Pilze aus dem **Stylized Nature MegaKit**, Häuser, Wagen, Kisten und Zäune aus dem **Medieval Village MegaKit** (beide von Quaternius, CC0), düster eingefärbt.
- Gelände mit Gras-, Erd- und Felstexturen.
- Deutlich hellere, gut lesbare Nacht (Mondlicht), Start in der Abenddämmerung, **Helligkeitsregler** (Titel und Systemmenü).
- Für das Handy optimiert: Meshes zusammengefasst, Sichtweiten, ferne Bäume als einfache Ersatzmodelle.

## v0.3 – Offene Welt, Akt 1 „Die Erste Nacht“

- **Offene Welt:** 560 × 560 m Gelände mit Fluss, See, Wäldern, Wegen. Ruinen der Alten, Dorf Asch-Furt, Krähes Banditenlager, Wachturm, Schrein, Landerwrack, Obelisken mit Lore.
- **Tag und Nacht in Echtzeit** (1 Spielminute pro Sekunde), Regen, Himmel mit Monden und Schleier.
- **Menschlichkeit 0–100:** bestimmt Aussehen, Sonnenschaden, Nachtkraft und wie Menschen auf dich reagieren.
- **Trinken mit Folgen:** nippen (Opfer überlebt, erinnert sich vielleicht an dich) oder aussaugen (Opfer stirbt). Am besten von hinten oder im Schlaf. Zeugen machen dich im Dorf zum Ausgestoßenen.
- **Blutsinn:** Herzschläge durch Wände sehen.
- **Sonne brennt:** Schatten, Wald und Häuser schützen.
- **Dorfleben:** Bewohner arbeiten, sitzen abends am Feuer und schlafen nachts in ihren Betten.
- **Akt 1:** Tamas am Weg → Asch-Furt → Jory im Käfig (die Wacht hängt ihn bei Sonnenaufgang) → Krähe → Finale an der Ruine. Jede Wahl ist endgültig und steht in der Chronik.
- **Ein einziger Spielstand,** automatisch gespeichert. Kein Zurück.
- LitRPG-System: Stufen, Attribute, Fähigkeiten, Ausrüstung mit Seltenheiten, Laden, tägliche Aufgaben.

## Fremde Assets

- Quaternius – Stylized Nature MegaKit (CC0 1.0), `assets/nature/`
- Quaternius – Medieval Village MegaKit (CC0 1.0), `assets/village/`
- Quaternius – Universal Base Characters, Modular Character Outfits – Fantasy, Universal Animation Library 1+2 (CC0 1.0), `assets/chars/` – aufbereitet über [moritzbrantner/asset-tooling](https://github.com/moritzbrantner/asset-tooling)
- Quaternius – Fantasy-Requisiten (Greyhaven-Starter, CC0 1.0), `assets/props/`

## Build

Jeder Push auf `main` baut per GitHub Actions eine APK:
https://github.com/Crusha5/Vapier-System/releases/latest/download/sanguine-protocol.apk

Damit Updates ohne Neuinstallation gehen, das Repo-Secret `KEYSTORE_PASSWORD` setzen.
