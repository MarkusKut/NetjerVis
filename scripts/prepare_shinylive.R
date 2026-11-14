# Prepare public, browser-safe data for shinylive_app/.
# Execute locally after scripts/update_from_excel.R. Does not require Shinylive.
if (!file.exists("R/ui_config.R")) stop("Run from the NetjerVis project root")

read_csv <- function(name) {
  utils::read.csv(file.path("data", paste0(name, ".csv")),
    stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = c("", "NA"), fileEncoding = "UTF-8")
}

public_fields <- list(
  figures = c("figure_id", "object_id", "object_group", "Statue", "side",
    "Position", "Register", "Stelle", "Bildfeld", "Gottheit", paste0("Epitheton", 1:5),
    "Inschrift", "Geschlecht", "Haltung", "Haltung_weiteres", "Koerper", "Kopf",
    "Kopfschmuck", "Handhaltung", "Objekte_in_Haenden", "Szene",
    "Text_vor_Gott", "Literatur", "Bemerkungen", "sonstiges", "Basis", "Zusatz"),
  objects = c("object_id", "object_group", "ref", "Statue", "Statue_Art", "Standort",
    "Inventarnummer", "alte_Inventarnummern", "Material", "Herkunft",
    "Herkunft_Bemerkung", "Provenienz", "Datierung", "Erhaltungszustand",
    "Name_des_Statueninhabers", "Titel_des_Statueninhabers"),
  texts = c("text_id", "object_id", "Textart", "Position (grob)",
    "Position (genau)", "Anzahl Zeilen / Spalten", "Schreibrichtung",
    "Richtung", "Zeile / Kolumne", "Literatur", "Parallelen"),
  measurements = c("measurement_id", "object_id", "Hoehe", "Breite", "Tiefe", "Masse_Bemerkung")
)

app_dir <- "shinylive_app"
dir.create(file.path(app_dir, "data"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(app_dir, "www", "drawings", "generated"), recursive = TRUE, showWarnings = FALSE)

write_if_different <- function(data, destination) {
  temp <- tempfile(fileext = ".csv")
  on.exit(unlink(temp), add = TRUE)
  utils::write.csv(data, temp, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  same <- file.exists(destination) &&
    identical(unname(tools::md5sum(temp)), unname(tools::md5sum(destination)))
  if (!same) file.copy(temp, destination, overwrite = TRUE)
  invisible(!same)
}

for (which in names(public_fields)) {
  data <- read_csv(which)
  fields <- public_fields[[which]]
  for (missing in setdiff(fields, names(data))) data[[missing]] <- NA_character_
  data <- data[, fields, drop = FALSE]
  write_if_different(data, file.path(app_dir, "data", paste0(which, ".csv")))
}

# The public app must never expose private local source_file paths.
web <- read_csv("drawings_web")
required <- c("figure_id", "public_url", "status")
if (!all(required %in% names(web))) stop("drawings_web.csv is missing required columns")
web <- web[!is.na(web$figure_id) & !is.na(web$public_url) &
  web$status == "ready" &
  grepl("^drawings/generated/[A-Za-z0-9._-]+$", web$public_url), required, drop = FALSE]
web <- web[file.exists(file.path("www", web$public_url)), , drop = FALSE]
web <- web[!duplicated(web$figure_id), , drop = FALSE]
write_if_different(web, file.path(app_dir, "data", "images.csv"))

# Include only ready drawings. Never copy or expose the original filesystem paths.
asset_dir <- file.path(app_dir, "www", "drawings", "generated")
for (name in unique(basename(web$public_url))) {
  source <- file.path("www", "drawings", "generated", name)
  target <- file.path(asset_dir, name)
  replace <- !file.exists(target) ||
    !identical(unname(tools::md5sum(source)), unname(tools::md5sum(target)))
  if (replace && !file.copy(source, target, overwrite = TRUE)) stop("Cannot stage SVG: ", name)
}
old <- list.files(asset_dir, full.names = TRUE)
if (length(old)) {
  obsolete <- old[!basename(old) %in% basename(web$public_url)]
  if (length(obsolete)) unlink(obsolete)
}

# One user-editable R file controls the interface. No duplicate configuration.
config_source <- "R/ui_config.R"
config_target <- file.path(app_dir, "config.R")
changed <- !file.exists(config_target) ||
  !identical(unname(tools::md5sum(config_source)), unname(tools::md5sum(config_target)))
if (changed) file.copy(config_source, config_target, overwrite = TRUE)
message("Shinylive public dataset prepared: ", nrow(read_csv("figures")),
  " figures, ", nrow(read_csv("objects")), " objects, ", nrow(web), " drawings.")
