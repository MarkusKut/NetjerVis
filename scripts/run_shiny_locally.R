# Local Shiny preview; does not require Shinylive export or Quarto.
if (!requireNamespace("shiny", quietly = TRUE)) stop("Install shiny")
source("scripts/update_from_excel.R", local = TRUE)
source("scripts/prepare_shinylive.R", local = TRUE)
shiny::runApp("shinylive_app")
