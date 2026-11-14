# Weitere Objektgruppen

Optionale Erweiterung für die bestehende `scripts/prepare_data.R`.

Pro Objektgruppe ein Verzeichnis anlegen:

```
source/other-groups/stelen/
  objects.csv
  figures.csv
  texts.csv         # optional
  measurements.csv  # optional
  layouts.csv       # optional
```

Die Gruppennamen dürfen nur Buchstaben, Ziffern und Unterstriche enthalten.

Pflichtfelder in `objects.csv`: `object_id`, `ref`, `Statue`.
Die `object_id` muss das Gruppenpräfix enthalten (z. B. `stelen:objekt123`).

Pflichtfelder in `figures.csv`: `figure_id`, `object_id`.
Die `figure_id` muss das Gruppenpräfix enthalten (z. B. `stelen:objekt123:figur001`).
Für die visuellen Filter können zusätzlich `Gottheit`, `Kopf`, `Koerper`,
`Kopfschmuck`, `Haltung`, `Szene`, `Register`, `Position`, `Bildfeld`,
`image_path` usw. belegt werden.

`texts.csv` benötigt `text_id` und `object_id`; `measurements.csv`
benötigt `measurement_id` und `object_id`.

Nach dem Ergänzen der Quelldateien lokal `source("scripts/build_static_site.R")`
ausführen und die Quarto-Website neu rendern. Die Frontend-Oberfläche liest
automatisch die Objektgruppen aus dem neuen JSON.
