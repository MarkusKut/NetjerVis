install.packages(c("readr", "readxl", "dplyr", "tibble", "DBI", "RSQLite", "jsonlite"))

# Force Excel re-import
options(catalog.force_refresh = TRUE)

# Update CSVs, SQLite, statue pages, and SVG copies
source("scripts/update_from_excel.R")

# Restore normal automatic change detection
options(catalog.force_refresh = FALSE)



source("scripts/sync_drawings.R")
table(readr::read_csv("data/drawings_web.csv", show_col_types=FALSE)$status)

