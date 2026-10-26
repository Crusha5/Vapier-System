# Sanguine Protocol

Open-World-RPG für Android (Godot 4.7, Compatibility-Renderer), düster-stilisiert. Kamera von hinten oder Ego-Perspektive, jederzeit umschaltbar.

**Veyra** – eine Kolonie, seit zwölf Jahren vom **Schleier** (einem roten Sturm) von der Erde abgeschnitten. Soldat **Kael** hat sich geweigert, das Dorf Morrow niederzubrennen. Kommandant Varek hat ihn erschossen und in den Ruinen der Alten liegen lassen. Dort erweckt ihn **die Erste Nacht** – als Blutgeborenen, mit einem Protokoll im Kopf.

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

## Build

Jeder Push auf `main` baut per GitHub Actions eine APK:
https://github.com/Crusha5/Vapier-System/releases/latest/download/sanguine-protocol.apk

Damit Updates ohne Neuinstallation gehen, das Repo-Secret `KEYSTORE_PASSWORD` setzen.
