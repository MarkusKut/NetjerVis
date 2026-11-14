# Quarto project pre-render. Execute from the project root.
# 1. Local Excel refresh (or prepared CSV fallback).
# 2. Generate the one-page-per-object Quarto catalogue.
# 3. Prepare portable Shiny/browser data + SVGs.
# 4. Export a Shinylive app only when its inputs change.
if (!file.exists("R/data_config.R")) stop("Run from the NetjerVis project root")
source("scripts/update_from_excel.R", local = TRUE)
source("scripts/generate_object_pages.R", local = TRUE)
source("scripts/prepare_shinylive.R", local = TRUE)
if (!requireNamespace("shinylive", quietly = TRUE)) {
  stop("Install Shinylive before rendering: install.packages('shinylive')")
}

app_files <- list.files("shinylive_app", recursive = TRUE, full.names = TRUE,
  include.dirs = FALSE)
app_files <- app_files[!dir.exists(app_files)]
if (!length(app_files)) stop("Shinylive source app is missing")
# Fingerprint content + paths. Avoid exporting the runtime for ordinary Quarto text edits.
fingerprint <- paste(basename(app_files), unname(tools::md5sum(app_files)), collapse = "\n")
state <- "data/.shinylive_build_fingerprint"
destination <- "www/shinylive"
ready <- file.exists(file.path(destination, "index.html"))
unchanged <- file.exists(state) && identical(paste(readLines(state, warn = FALSE), collapse = "\n"), fingerprint)
if (!ready || !unchanged) {
  message("Exporting Shinylive application into ", destination)
  shinylive::export(appdir = "shinylive_app", destdir = destination,
    wasm_packages = TRUE, quiet = FALSE,
    template_params = list(title = "NetjerVis – Interaktive Forschungsdatenbank"))
  if (!file.exists(file.path(destination, "index.html"))) stop("Shinylive export did not produce index.html")
  writeLines(fingerprint, state, useBytes = TRUE)
} else {
  message("Shinylive inputs unchanged; reusing existing browser application assets.")
}
