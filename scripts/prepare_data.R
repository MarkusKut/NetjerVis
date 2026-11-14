# Rebuild the catalogue from the original Excel workbook.
# Run from the project root: source("scripts/prepare_data.R")
# The drawing manifest is preserved across refreshes.

required <- c("readxl", "readr", "dplyr", "tibble")
missing_packages <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) stop("Install R packages: ", paste(missing_packages, collapse = ", "))

source("R/data_config.R", local = TRUE)
workbook <- excel_workbook
if (!file.exists(workbook)) {
  stop("Excel workbook not found: ", workbook,
       ". Change excel_workbook in R/data_config.R or copy your workbook there.")
}

expected_sheets <- c("statuen_goetter", "statuen_ges", "texte", "layout_data")

missing_sheets <- setdiff(expected_sheets, readxl::excel_sheets(workbook))
if (length(missing_sheets)) {
  stop("Missing worksheets in ", workbook, ": ", paste(missing_sheets, collapse = ", "))
}

dir.create("data", showWarnings = FALSE)


library(dplyr)

first_known <- function(x) {
  idx <- which(!is.na(x) & trimws(as.character(x)) != "")
  if (length(idx)) as.character(x[[idx[[1]]]]) else NA_character_
}

make_object_id <- function(x, ref) (paste0(tolower(x), ":", ref))

load_sheet <- function(sheet) {
  readxl::read_excel(workbook, sheet = sheet, na = c("", "NA", "---")) |>
    mutate(across(where(is.character), ~ na_if(trimws(.x), "")))
}



source_objects <- load_sheet("statuen_ges")

object_columns <- c(
  "label", "label_short", "Statue_Art", "Objektgruppe", "Standort", "Inventarnummer",
  "alte_Inventarnummern", "Material", "Herkunft", "Herkunft_Bemerkung",
  "Provenienz", "Datierung", "Erhaltungszustand",
  "Name_des_Statueninhabers", "Titel_des_Statueninhabers"
)

objects <- source_objects |>
  group_by(ref) |>
  summarise(across(all_of(object_columns), first_known), .groups = "drop") |>
  mutate(
    Statue = coalesce(label_short, label, ref),
    object_id = make_object_id(Objektgruppe, ref),
    object_group = Objektgruppe
  ) |>
  relocate(object_id, object_group, ref, Statue) %>%
  arrange(ref, .locale = "de") %>% 
  filter(!Statue_Art %in% c("Sockel", "Kopf"))




figures <- load_sheet("statuen_goetter") %>%
  left_join(
    objects %>% select(ref, Objektgruppe),
    by = "ref"
  ) %>%
  mutate(
    figure_id = paste0(tolower(Objektgruppe), ":", ref, ":", as.character(`id.2`)),
    object_id = make_object_id(tolower(Objektgruppe), ref),
    object_group = Objektgruppe,
    side = case_when(
      substr(as.character(Bildfeld), 1, 1) == "1" ~ "Vorderseite",
      substr(as.character(Bildfeld), 1, 1) == "2" ~ "Rückenpfeiler",
      substr(as.character(Bildfeld), 1, 1) == "3" ~ "Rechte Seite",
      substr(as.character(Bildfeld), 1, 1) == "4" ~ "Linke Seite",
      TRUE ~ "Unbestimmt"
    ),
    image_status = if_else(!is.na(image_path), "linked_missing", "not_linked")
  ) |>
  relocate(figure_id, object_id, object_group, side, image_status)




measurements <- source_objects %>%
  mutate(
    measurement_id = paste0(tolower(Objektgruppe), ":measure:", row_number()),
    object_id = make_object_id(Objektgruppe, ref),
    source_row_id = as.character(id)
  ) |>
  select(measurement_id, object_id, ref, source_row_id,
         Hoehe, Breite, Tiefe, Masse_Bemerkung)


texts <- load_sheet("texte") %>%
  left_join(
    objects %>% select(ref, Objektgruppe),
    by = "ref"
  ) |>
  mutate(
    text_id = paste0(tolower(Objektgruppe), ":", ref, ":text:", id),
    object_id = make_object_id(Objektgruppe, ref), object_group = Objektgruppe
  ) |>
  relocate(text_id, object_id, object_group)

layouts <- load_sheet("layout_data") %>%
  left_join(
    objects %>% select(ref, Objektgruppe),
    by = "ref"
  ) |>
  mutate(object_id = make_object_id(Objektgruppe, ref), object_group = Objektgruppe) |>
  relocate(object_id, object_group)

# Optional additional object groups. Each group has its own folder in
# source/other-groups/<group>/ and can provide objects.csv plus optional
# figures.csv, texts.csv, measurements.csv and layouts.csv.
# All groups keep the core catalogue keys; group-specific fields are retained.
external_root <- "source/other-groups"
if (dir.exists(external_root)) {
  group_dirs <- list.dirs(external_root, recursive = FALSE)
  for (folder in group_dirs) {
    group <- basename(folder)
    if (!grepl("^[A-Za-z0-9_]+$", group)) stop("Unsafe object group: ", group)
    object_csv <- file.path(folder, "objects.csv")
    if (!file.exists(object_csv)) next
    external <- function(table) {
      path <- file.path(folder, paste0(table, ".csv"))
      if (!file.exists(path)) return(NULL)
      readr::read_csv(path, show_col_types = FALSE,
                       col_types = readr::cols(.default = readr::col_character()),
                       na = c("", "NA"))
    }
    ext_objs <- external("objects")
    for (k in c("object_id", "ref", "Statue")) {
      if (!k %in% names(ext_objs)) stop("Missing ", k, " in ", object_csv)
    }
    ext_objs$object_group <- group
    if (any(!startsWith(ext_objs$object_id, paste0(group, ":"))))
      stop("Foreign object_id prefix in ", object_csv)
    objects <- dplyr::bind_rows(dplyr::mutate(objects, across(everything(), as.character)), ext_objs)

    ext_fig <- external("figures")
    if (!is.null(ext_fig)) {
      for (k in c("figure_id", "object_id")) if (!k %in% names(ext_fig))
        stop("Missing ", k, " in ", folder, "/figures.csv")
      ext_fig$object_group <- group
      if (any(!startsWith(ext_fig$figure_id, paste0(group, ":")))) stop("Wrong figure ID prefix: ", group)
      if (!"Statue" %in% names(ext_fig)) {
        ext_fig$Statue <- ext_objs$Statue[match(ext_fig$object_id, ext_objs$object_id)]
      }
      if (!"side" %in% names(ext_fig)) ext_fig$side <- "Unbestimmt"
      if (!"image_path" %in% names(ext_fig)) ext_fig$image_path <- NA_character_
      if (!"image_status" %in% names(ext_fig)) ext_fig$image_status <- "not_linked"
      figures <- dplyr::bind_rows(dplyr::mutate(figures, across(everything(), as.character)), ext_fig)
    }
    for (table in c("texts", "measurements", "layouts")) {
      extra <- external(table)
      if (is.null(extra)) next
      if (!"object_id" %in% names(extra)) stop("Missing object_id in ", folder, "/", table, ".csv")
      if (table == "texts") {
        if (!"text_id" %in% names(extra)) stop("Missing text_id in ", folder)
        texts <- dplyr::bind_rows(dplyr::mutate(texts, across(everything(), as.character)), extra)
      } else if (table == "measurements") {
        if (!"measurement_id" %in% names(extra)) stop("Missing measurement_id in ", folder)
        measurements <- dplyr::bind_rows(dplyr::mutate(measurements, across(everything(), as.character)), extra)
      } else {
        layouts <- dplyr::bind_rows(dplyr::mutate(layouts, across(everything(), as.character)), extra)
      }
    }
  }
}
if (anyDuplicated(objects$object_id)) stop("Duplicate object_id")
if (anyDuplicated(figures$figure_id)) stop("Duplicate figure_id")
if (any(!figures$object_id %in% objects$object_id)) stop("Unmatched figure object_id")

# This is the user-editable relation from figure identifiers to SVG/PNG assets.
# For example: figure_id=heilstatuen:helioFrag:1, file=drawings/helioFrag_001.svg
manifest_path <- "data/drawings_manifest.csv"
manifest_columns <- c("figure_id", "file", "register_height_original",
                      "register_height_target", "scale_verified", "attribution", "rights")
if (file.exists(manifest_path)) {
  old <- readr::read_csv(manifest_path,
                         col_types = readr::cols(.default = readr::col_character()),
                         show_col_types = FALSE)
  for (name in setdiff(manifest_columns, names(old))) old[[name]] <- NA_character_
  old <- old |> distinct(figure_id, .keep_all = TRUE) |>
    select(all_of(manifest_columns))
} else {
  old <- tibble::tibble(figure_id = character())
  for (name in setdiff(manifest_columns, names(old))) old[[name]] <- character()
}
manifest <- figures |>
  distinct(figure_id, image_path) |>
  left_join(old, by = "figure_id") |>
  mutate(file = image_path) |>
  select(all_of(manifest_columns))

readr::write_csv(figures, "data/figures.csv", na = "")
readr::write_csv(objects, "data/objects.csv", na = "")
readr::write_csv(measurements, "data/measurements.csv", na = "")
readr::write_csv(texts, "data/texts.csv", na = "")
readr::write_csv(layouts, "data/layouts.csv", na = "")
readr::write_csv(manifest, manifest_path, na = "")

# Optional relational SQLite database; all other project parts work from CSV too.
if (requireNamespace("DBI", quietly = TRUE) && requireNamespace("RSQLite", quietly = TRUE)) {
  db <- DBI::dbConnect(RSQLite::SQLite(), "data/catalog.sqlite")
  DBI::dbExecute(db, "PRAGMA foreign_keys = ON")
  for (table_name in c("drawings_manifest", "figures", "measurements", "texts", "layouts", "objects")) {
    if (DBI::dbExistsTable(db, table_name)) DBI::dbRemoveTable(db, table_name)
  }
  DBI::dbWriteTable(db, "objects", objects)
  DBI::dbWriteTable(db, "figures", figures)
  DBI::dbWriteTable(db, "measurements", measurements)
  DBI::dbWriteTable(db, "texts", texts)
  DBI::dbWriteTable(db, "layouts", layouts)
  DBI::dbWriteTable(db, "drawings_manifest", manifest)
  DBI::dbExecute(db, "CREATE UNIQUE INDEX IF NOT EXISTS idx_objects_id ON objects(object_id)")
  DBI::dbExecute(db, "CREATE UNIQUE INDEX IF NOT EXISTS idx_figures_id ON figures(figure_id)")
  DBI::dbExecute(db, "CREATE INDEX IF NOT EXISTS idx_figures_object ON figures(object_id)")
  DBI::dbExecute(db, "CREATE INDEX IF NOT EXISTS idx_figures_name ON figures(Gottheit)")
  DBI::dbDisconnect(db)
}

message(sprintf("Prepared %s objects, %s figures, %s texts, %s measurement rows.",
                nrow(objects), nrow(figures), nrow(texts), nrow(measurements)))

