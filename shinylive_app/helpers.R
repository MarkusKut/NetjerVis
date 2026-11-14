# NetjerVis Shiny helpers: browser-safe, base R + Shiny only.
# There are no external Excel files, local source paths, databases or server calls.

read_public_csv <- function(name) {
  path <- file.path("data", paste0(name, ".csv"))
  if (!file.exists(path)) stop("Published data file missing: ", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE,
                  na.strings = c("", "NA"), fileEncoding = "UTF-8")
}

figure_data <- read_public_csv("figures")
object_data <- read_public_csv("objects")
text_data <- read_public_csv("texts")
measurement_data <- read_public_csv("measurements")
image_data <- read_public_csv("images")

# A published image has a relative URL within the app's own www directory.
image_map <- stats::setNames(image_data$public_url, image_data$figure_id)

field <- function(record, key) {
  if (is.null(record) || !nrow(record) || !key %in% names(record)) return(NA_character_)
  as.character(record[[key]][[1L]])
}

label_value <- function(value, fallback = "—") {
  if (!length(value) || is.na(value[[1L]]) ||
      !nzchar(trimws(as.character(value[[1L]])))) return(fallback)
  as.character(value[[1L]])
}

image_url <- function(figure_id) {
  v <- unname(image_map[as.character(figure_id)])
  if (!length(v) || is.na(v[[1L]]) || !nzchar(v[[1L]])) return(NULL)
  v[[1L]]
}

has_image <- function(figure_id) {
  !is.null(image_url(figure_id))
}

fig_tag <- function(figure_id, small = FALSE) {
  url <- image_url(figure_id)
  if (is.null(url)) return(shiny::tags$div(class = "image-placeholder", "Keine Zeichnung vorhanden"))
  shiny::tags$img(
    src = url,
    alt = paste("Vektorzeichnung", as.character(figure_id)),
    class = if (small) "svg-small" else "svg-large",
    loading = "lazy"
  )
}

meta_row <- function(label, value) {
  shiny::tags$div(class = "meta-row",
    shiny::tags$span(class = "meta-label", label),
    shiny::tags$span(class = "meta-value", label_value(value)))
}

figure_card <- function(record, compact = FALSE) {
  id <- field(record, "figure_id")
  if (is.na(id)) return(NULL)
  info <- shiny::tagList(
    shiny::tags$div(class = "figure-uid", id),
    shiny::tags$h4(label_value(field(record, "Gottheit"), "Nicht bestimmt")),
    shiny::tags$p(class = "card-note", label_value(field(record, "Statue"))),
    shiny::tags$p(class = "card-note",
      paste(label_value(field(record, "Position")),
            " · Reg.", label_value(field(record, "Register")),
            " · St.", label_value(field(record, "Stelle"))))
  )
  if (!compact) {
    info <- shiny::tagList(info, lapply(names(nv_settings$detail_fields), function(k) {
      meta_row(nv_settings$detail_fields[[k]], field(record, k))
    }))
  }
  shiny::tags$article(class = if (compact) "figure-card compact" else "figure-card",
    shiny::tags$div(class = "drawing-frame", fig_tag(id)),
    shiny::tags$div(class = "figure-description", info))
}

choice_list <- function(values, all = FALSE) {
  values <- sort(unique(as.character(values[!is.na(values) & nzchar(trimws(values))])))
  if (all) c("Alle" = "__ALL__", stats::setNames(values, values))
  else stats::setNames(values, values)
}

choice_labels <- function(df) {
  labels <- paste0(
    vapply(df$Gottheit, label_value, character(1), fallback = "Unbestimmt"),
    " · ", df$Statue, " · Reg. ", df$Register,
    " · St. ", df$Stelle, " · ", df$figure_id)
  stats::setNames(df$figure_id, labels)
}

# Build a simple paginated table using native Shiny components; no DT dependency.
html_table <- function(data, columns, actions = FALSE) {
  kept <- names(columns)[names(columns) %in% names(data)]
  headings <- as.character(columns[kept])
  header_cells <- lapply(headings, shiny::tags$th)
  if (actions) header_cells <- c(list(shiny::tags$th("Auswahl")), header_cells)
  rows <- lapply(seq_len(nrow(data)), function(i) {
    cells <- lapply(kept, function(nm) {
      val <- data[[nm]][[i]]
      shiny::tags$td(label_value(val))
    })
    if (actions) cells <- c(list(shiny::tags$td(
      shiny::actionLink(paste0("pick_row_", i), "Ansehen"))), cells)
    do.call(shiny::tags$tr, cells)
  })
  shiny::tags$div(class = "table-scroll",
    shiny::tags$table(class = "nv-table",
      shiny::tags$thead(do.call(shiny::tags$tr, header_cells)),
      shiny::tags$tbody(rows)))
}

count_format <- function(value) format(as.integer(value), big.mark = ".", trim = TRUE)
