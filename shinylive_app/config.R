# NetjerVis presentation configuration (R only).
# Edit labels, fields, page sizes, and comparison limits here.
# scripts/prepare_shinylive.R copies this configuration into the browser app.

nv_settings <- list(
  title = "NetjerVis",
  sidebar_width = 285L,
  page_size = 12L,
  gallery_page_size = 24L,
  object_page_size = 15L,
  compare_limit = 4L,
  filter_fields = c(
    object_group = "Objektgruppe",
    object_id = "Objekt",
    Gottheit = "Gottheit",
    side = "Objektseite",
    Koerper = "Körper",
    Kopf = "Kopf",
    Kopfschmuck = "Kopfschmuck",
    Haltung = "Haltung"
  ),
  catalogue_columns = c(
    figure_id = "Figur-ID",
    Statue = "Objekt",
    side = "Seite",
    Register = "Register",
    Bildfeld = "Bildfeld",
    Gottheit = "Gottheit",
    Haltung = "Haltung",
    Koerper = "Körper",
    Kopf = "Kopf",
    Kopfschmuck = "Kopfschmuck",
    Szene = "Szene"
  ),
  detail_fields = c(
    Gottheit = "Gottheit",
    Geschlecht = "Geschlecht",
    Haltung = "Haltung",
    Koerper = "Körper",
    Kopf = "Kopf",
    Kopfschmuck = "Kopfschmuck",
    Handhaltung = "Handhaltung",
    Objekte_in_Haenden = "Objekte in Händen",
    Szene = "Szene",
    Inschrift = "Inschrift",
    Text_vor_Gott = "Beischrift",
    Literatur = "Literatur",
    Bemerkungen = "Bemerkungen"
  ),
  compare_fields = c(
    Gottheit = "Gottheit",
    Geschlecht = "Geschlecht",
    Haltung = "Haltung",
    Koerper = "Körper",
    Kopf = "Kopf",
    Kopfschmuck = "Kopfschmuck",
    Handhaltung = "Handhaltung",
    Objekte_in_Haenden = "Objekte in Händen",
    Szene = "Szene",
    Register = "Register",
    Bildfeld = "Bildfeld"
  )
)
