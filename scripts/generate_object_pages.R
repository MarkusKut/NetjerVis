# Regenerate one static Quarto record per object (not per figure).
# Custom observations belong in objekte/_notes/SLUG.md, never overwritten.
if (!file.exists("data/objects.csv")) stop("Run from project root")
rd <- function(name) utils::read.csv(file.path("data", paste0(name, ".csv")),
  check.names = FALSE, stringsAsFactors = FALSE, na.strings = c("", "NA"), fileEncoding = "UTF-8")
objects <- rd("objects")
figures <- rd("figures")
texts <- rd("texts")
measures <- rd("measurements")
images <- rd("drawings_web")
images <- images[images$status == "ready" & !is.na(images$public_url), , drop = FALSE]
images <- images[file.exists(file.path("www", images$public_url)), , drop = FALSE]
image_map <- stats::setNames(images$public_url, images$figure_id)

mk <- function(s) {
  if (!length(s) || is.na(s[[1]]) || !nzchar(trimws(as.character(s[[1]])))) return("—")
  x <- gsub("[\r\n]+", " ", as.character(s[[1]]))
  x <- gsub("|", "\\\\|", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}
header <- function(title) {
  title <- gsub('"', "'", title, fixed = TRUE)
  c("---", paste0('title: "', title, '"'), 'page-layout: full', 'toc: true', "---", "")
}
static_table <- function(df, columns) {
  keys <- names(columns)[names(columns) %in% names(df)]
  if (!nrow(df) || !length(keys)) return("Keine Einträge erfasst.")
  rows <- apply(df[, keys, drop = FALSE], 1L, function(v) {
    paste0("| ", paste(vapply(as.list(v), mk, character(1)), collapse = " | "), " |")
  })
  c(paste0("| ", paste(unname(columns[keys]), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(keys)), collapse = " | "), " |"), rows)
}

dir.create("objekte", showWarnings = FALSE)
dir.create("objekte/_notes", recursive = TRUE, showWarnings = FALSE)
slugs <- paste0(objects$object_group, "__", gsub("[^A-Za-z0-9_]", "_", objects$ref))
pages <- file.path("objekte", paste0(slugs, ".qmd"))
if (anyDuplicated(pages)) stop("Object pages collide; check group and reference")
managed <- "data/generated_object_pages.txt"
old <- if (file.exists(managed)) readLines(managed, warn = FALSE) else character()
for (stale in setdiff(old, pages)) if (file.exists(stale)) unlink(stale)

for (i in seq_len(nrow(objects))) {
  o <- objects[i, , drop = FALSE]
  slug <- slugs[[i]]
  note <- file.path("objekte", "_notes", paste0(slug, ".md"))
  if (!file.exists(note)) writeLines(c("Eigene Ergänzungen zu diesem Objekt können hier eingetragen werden."), note, useBytes = TRUE)
  props <- c(Statue_Art = "Objekttyp", Standort = "Standort", Inventarnummer = "Inventarnummer",
    Material = "Material", Herkunft = "Herkunft", Provenienz = "Provenienz",
    Datierung = "Datierung", Erhaltungszustand = "Erhaltungszustand")
  lines <- header(paste("Objektblatt:", as.character(o$Statue[[1]])))
  lines <- c(lines, "[Zum interaktiven Figurenkatalog](../datenbank.qmd)", "", "## Objektangaben", "")
  for (k in names(props)) if (k %in% names(o)) lines <- c(lines,
    paste0("**", props[[k]], ":** ", mk(o[[k]])), "")
  fs <- figures[figures$object_id == o$object_id[[1]], , drop = FALSE]
  if (nrow(fs)) {
    fs$Zeichnung <- vapply(fs$figure_id, function(id) {
      link <- unname(image_map[id])
      if (!length(link) || is.na(link[[1L]])) return("—")
      paste0("![SVG](../www/", link[[1L]], "){width=70px}")
    }, character(1))
  }
  lines <- c(lines, "## Figuren", "", paste(nrow(fs), "Figuren erfasst."), "",
    static_table(fs, c(Zeichnung="Zeichnung", figure_id="Figur-ID", side="Objektseite",
      Register="Register", Stelle="Stelle", Gottheit="Gottheit", Szene="Szene")), "")
  ts <- texts[texts$object_id == o$object_id[[1]], , drop = FALSE]
  ms <- measures[measures$object_id == o$object_id[[1]], , drop = FALSE]
  lines <- c(lines, "## Texte", "", static_table(ts, c(Textart="Textart",
    "Position (grob)"="Position (grob)", Literatur="Literatur")), "",
    "## Maße", "", static_table(ms, c(Hoehe="Höhe", Breite="Breite", Tiefe="Tiefe",
    Masse_Bemerkung="Bemerkungen")), "",
    "## Ergänzende Anmerkungen", "",
    paste0("{{< include _notes/", slug, ".md >}}"), "")
  writeLines(lines, pages[[i]], useBytes = TRUE)
}
index <- c("---", 'title: "Objektkatalog"', "---", "",
  "Ein Datenblatt pro Objekt. Die Figuren werden als Datensätze innerhalb der Objekte geführt.", "")
for (i in seq_len(nrow(objects))) index <- c(index,
  paste0("- [", mk(objects$Statue[[i]]), "](./", slugs[[i]], ".qmd)"))
writeLines(index, "objekte/index.qmd", useBytes = TRUE)
writeLines(pages, managed, useBytes = TRUE)
message("Quarto object pages prepared: ", nrow(objects))
