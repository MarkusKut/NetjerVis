# NetjerVis – native R Shiny application, prepared for Shinylive/webR.
# All application logic is in R. The browser runtime is provided by Shiny/Shinylive.
library(shiny)
library(bslib)
source("config.R", local = TRUE)
source("helpers.R", local = TRUE)

if (!nrow(figure_data) || !nrow(object_data)) stop("Published catalogue is empty")

object_choices <- stats::setNames(object_data$object_id, object_data$Statue)
figure_choices <- choice_labels(figure_data)

make_filter <- function(key, title) {
  if (!key %in% names(figure_data)) return(NULL)
  vals <- if (identical(key, "object_id")) {
    c("Alle" = "__ALL__", object_choices)
  } else {
    choice_list(figure_data[[key]], all = TRUE)
  }
  shiny::selectInput(paste0("filter_", key), title, choices = vals, selected = "__ALL__")
}

filter_ui <- lapply(names(nv_settings$filter_fields), function(key) {
  make_filter(key, nv_settings$filter_fields[[key]])
})

ui <- shiny::fluidPage(
  title = nv_settings$title,
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly",
    bg = "#fbfaf7", fg = "#273740", primary = "#344d5b"),
  shiny::tags$head(
    shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    shiny::tags$link(rel = "stylesheet", href = "site.css")
  ),
  # The Quarto website already supplies the NetjerVis title: no duplicated heading here.
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Recherchefilter", open = "desktop",
      width = as.integer(nv_settings$sidebar_width), id = "research_sidebar",
      filter_ui,
      shiny::textInput("free_text", "Freitextsuche", placeholder = "Szene, Epitheton, Literatur …"),
      shiny::checkboxInput("only_images", "Nur Figuren mit Zeichnung", FALSE),
      shiny::actionButton("clear_filters", "Filter zurücksetzen", class = "btn-outline-secondary"),
      shiny::p(class = "help-note", "Filter gelten für Figurenkatalog und Zeichnungsgalerie.")
    ),
    shiny::tabsetPanel(id = "view", type = "tabs",
      shiny::tabPanel("Figurenkatalog", value = "catalogue",
        shiny::div(class = "section-intro",
          shiny::uiOutput("count_text"),
          shiny::downloadButton("download_filtered", "CSV herunterladen")
        ),
        shiny::div(class = "pager",
          shiny::numericInput("catalogue_page", "Seite", value = 1, min = 1, step = 1, width = "110px"),
          shiny::uiOutput("catalogue_page_label")
        ),
        shiny::uiOutput("catalogue_table"),
        shiny::tags$h3("Datenblatt der ausgewählten Figur"),
        shiny::uiOutput("figure_detail"),
        shiny::actionButton("add_compare", "Zum Vergleich hinzufügen", class = "btn-primary")
      ),
      shiny::tabPanel("Zeichnungsgalerie", value = "gallery",
        shiny::p(class = "help-note", "Visuelle Übersicht passender Figuren. Die Auswahl folgt den Recherchefiltern."),
        shiny::div(class = "pager",
          shiny::numericInput("gallery_page", "Seite", value = 1, min = 1, step = 1, width = "110px"),
          shiny::uiOutput("gallery_page_label")
        ),
        shiny::uiOutput("gallery_cards")
      ),
      shiny::tabPanel("Figurenvergleich", value = "compare",
        shiny::p("Bis zu vier Darstellungen und ihre Merkmale nebeneinander vergleichen."),
        shiny::selectizeInput("selected_figures", "Vergleichsfiguren", choices = figure_choices,
          selected = utils::head(figure_data$figure_id, 2), multiple = TRUE,
          options = list(maxItems = as.integer(nv_settings$compare_limit))),
        shiny::uiOutput("comparison_cards"),
        shiny::tags$h3("Merkmalsmatrix"),
        shiny::uiOutput("comparison_matrix"),
        shiny::div(class = "caution", "Gleiche Bildschirmhöhe bedeutet nicht zwangsläufig gleiche archäologische Größe.")
      ),
      shiny::tabPanel("Statuendatenblatt", value = "object",
        shiny::selectInput("object_pick", "Objekt", choices = object_choices,
          selected = object_data$object_id[[1]]),
        shiny::uiOutput("object_overview"),
        shiny::tags$h3("Figuren"),
        shiny::div(class = "pager", shiny::numericInput("object_page", "Seite", 1,
          min = 1, step = 1, width = "110px"), shiny::uiOutput("object_page_label")),
        shiny::uiOutput("object_figure_table"),
        shiny::tags$h3("Texte"), shiny::uiOutput("object_text_table"),
        shiny::tags$h3("Maße und Maßeinträge"), shiny::uiOutput("object_measurement_table")
      ),
      shiny::tabPanel("Vorkommensmatrix", value = "matrix",
        shiny::div(class = "matrix-controls",
          shiny::selectInput("matrix_n", "Häufigste Gottheitsnamen", choices = c(15,25,40), selected = 25),
          shiny::selectInput("matrix_mode", "Darstellung", choices = c(
            "Dokumentiert / nicht dokumentiert" = "presence", "Anzahl der Nennungen" = "count"))
        ),
        shiny::uiOutput("matrix_table"),
        shiny::div(class = "caution", "Nicht dokumentiert bedeutet nicht historisch abwesend. Die Erhaltung und Dokumentation der Objekte sind unterschiedlich.")
      ),
      shiny::tabPanel("Datenqualität", value = "quality",
        shiny::uiOutput("quality_metrics"),
        shiny::tags$h3("Häufigste dokumentierte Gottheitsnamen"),
        shiny::plotOutput("deity_frequencies", height = "420px"),
        shiny::tags$h3("Fehlende Bildverknüpfungen"),
        shiny::uiOutput("missing_images_table"),
        shiny::tags$h3("Objekte ohne Figureneinträge"),
        shiny::uiOutput("unrepresented_objects_table"),
        shiny::tags$h3("Maßdatensätze ohne passende Objektkennung"),
        shiny::uiOutput("unassigned_measurements_table")
      )
    ),
    fillable = FALSE,
    border = FALSE
  )
)

server <- function(input, output, session) {
  # The full research corpus is bundled as read-only CSV files for each visitor.
  filtered <- shiny::reactive({
    d <- figure_data
    for (key in names(nv_settings$filter_fields)) {
      x <- input[[paste0("filter_", key)]]
      if (is.null(x) || length(x) != 1 || identical(x, "__ALL__")) next
      d <- d[!is.na(d[[key]]) & d[[key]] == x, , drop = FALSE]
    }
    term <- trimws(if (is.null(input$free_text)) "" else input$free_text)
    if (nzchar(term) && nrow(d)) {
      searchable <- intersect(c("Gottheit", "Szene", "Position", "Epitheton1",
        "Epitheton2", "Epitheton3", "Koerper", "Kopf", "Kopfschmuck",
        "Literatur", "Bemerkungen", "figure_id"), names(d))
      hits <- apply(d[, searchable, drop = FALSE], 1L, function(row) {
        any(grepl(tolower(term), tolower(as.character(row)), fixed = TRUE), na.rm = TRUE)
      })
      d <- d[hits, , drop = FALSE]
    }
    if (isTRUE(input$only_images) && nrow(d)) {
      d <- d[vapply(d$figure_id, has_image, logical(1)), , drop = FALSE]
    }
    d
  })

  observeEvent(input$clear_filters, {
    for (key in names(nv_settings$filter_fields)) {
      shiny::updateSelectInput(session, paste0("filter_", key), selected = "__ALL__")
    }
    shiny::updateTextInput(session, "free_text", value = "")
    shiny::updateCheckboxInput(session, "only_images", value = FALSE)
  })

  shiny::observeEvent(filtered(), {
    shiny::updateNumericInput(session, "catalogue_page", value = 1)
    shiny::updateNumericInput(session, "gallery_page", value = 1)
  }, ignoreInit = TRUE)

  # Close filters when showing a view that does not use them.
  shiny::observeEvent(input$view, {
    bslib::toggle_sidebar(id = "research_sidebar",
      open = input$view %in% c("catalogue", "gallery"), session = session)
  }, ignoreInit = TRUE)

  paginate <- function(data, page, size) {
    count <- nrow(data)
    pages <- max(1L, as.integer(ceiling(count / size)))
    page <- suppressWarnings(as.integer(page))
    if (is.na(page)) page <- 1L
    page <- max(1L, min(page, pages))
    if (!count) return(data[FALSE, , drop = FALSE])
    indices <- seq.int((page - 1L) * size + 1L, min(page * size, count))
    data[indices, , drop = FALSE]
  }
  catalogue_slice <- shiny::reactive(paginate(filtered(), input$catalogue_page,
    as.integer(nv_settings$page_size)))
  gallery_slice <- shiny::reactive(paginate(filtered(), input$gallery_page,
    as.integer(nv_settings$gallery_page_size)))

  output$count_text <- shiny::renderUI(shiny::tags$p(class = "count-text",
    shiny::tags$strong(count_format(nrow(filtered()))), " von ",
    count_format(nrow(figure_data)), " Figurenzeilen angezeigt"))
  output$catalogue_page_label <- shiny::renderUI({
    shiny::tags$span(class = "help-note", paste("von",
      max(1L, ceiling(nrow(filtered()) / nv_settings$page_size)), "Seiten"))
  })
  output$catalogue_table <- shiny::renderUI({
    x <- catalogue_slice()
    if (!nrow(x)) return(shiny::p("Keine passenden Datensätze."))
    html_table(x, nv_settings$catalogue_columns, actions = TRUE)
  })

  # A fixed number of lightweight Shiny action links selects the current table row.
  selected_id <- shiny::reactiveVal(figure_data$figure_id[[1L]])
  for (j in seq_len(max(1L, as.integer(nv_settings$page_size)))) {
    local({
      index <- j
      shiny::observeEvent(input[[paste0("pick_row_", index)]], {
        x <- catalogue_slice()
        if (nrow(x) >= index) selected_id(x$figure_id[[index]])
      }, ignoreInit = TRUE)
    })
  }
  current_figure <- shiny::reactive({
    d <- figure_data[match(selected_id(), figure_data$figure_id), , drop = FALSE]
    if (!nrow(d) || is.na(d$figure_id[[1L]])) return(NULL)
    d
  })
  output$figure_detail <- shiny::renderUI({
    f <- current_figure()
    if (is.null(f)) return(shiny::p("Keine Figur ausgewählt."))
    shiny::tags$div(class = "details-panel", figure_card(f))
  })
  output$download_filtered <- shiny::downloadHandler(
    filename = function() paste0("NetjerVis_Figuren_", Sys.Date(), ".csv"),
    content = function(file) utils::write.csv(filtered(), file, row.names = FALSE,
      na = "", fileEncoding = "UTF-8")
  )

  output$gallery_page_label <- shiny::renderUI(shiny::tags$span(class = "help-note",
    paste("von", max(1L, ceiling(nrow(filtered()) / nv_settings$gallery_page_size)), "Seiten")))
  output$gallery_cards <- shiny::renderUI({
    d <- gallery_slice()
    if (!nrow(d)) return(shiny::p("Keine passenden Zeichnungen."))
    shiny::tags$div(class = "figure-grid", lapply(seq_len(nrow(d)), function(i) {
      figure_card(d[i, , drop = FALSE], compact = TRUE)
    }))
  })

  shiny::observeEvent(input$add_compare, {
    f <- current_figure()
    if (is.null(f)) return()
    ids <- unique(c(input$selected_figures, f$figure_id[[1L]]))
    ids <- utils::tail(ids, as.integer(nv_settings$compare_limit))
    shiny::updateSelectizeInput(session, "selected_figures", selected = ids)
    shiny::updateTabsetPanel(session, "view", selected = "compare")
  })
  comparison <- shiny::reactive({
    ids <- utils::head(input$selected_figures, as.integer(nv_settings$compare_limit))
    ids <- ids[ids %in% figure_data$figure_id]
    figure_data[match(ids, figure_data$figure_id), , drop = FALSE]
  })
  output$comparison_cards <- shiny::renderUI({
    x <- comparison()
    if (!nrow(x)) return(shiny::p("Bitte Figuren auswählen."))
    shiny::tags$div(class = "comparison-grid", lapply(seq_len(nrow(x)), function(i) {
      figure_card(x[i, , drop = FALSE])
    }))
  })
  output$comparison_matrix <- shiny::renderUI({
    x <- comparison()
    if (!nrow(x)) return(NULL)
    cols <- names(nv_settings$compare_fields)
    result <- data.frame(Merkmal = unname(nv_settings$compare_fields),
      check.names = FALSE, stringsAsFactors = FALSE)
    for (i in seq_len(nrow(x))) {
      result[[paste("Figur", i)]] <- vapply(cols, function(k) label_value(field(x[i, , drop = FALSE], k)), character(1))
    }
    html_table(result, stats::setNames(names(result), names(result)))
  })

  object_entry <- shiny::reactive({
    x <- object_data[object_data$object_id == input$object_pick, , drop = FALSE]
    if (!nrow(x)) return(NULL)
    x[1L, , drop = FALSE]
  })
  output$object_overview <- shiny::renderUI({
    x <- object_entry()
    if (is.null(x)) return(shiny::p("Kein Objekt ausgewählt."))
    props <- c(Statue_Art = "Objekttyp", Standort = "Standort",
      Inventarnummer = "Inventarnummer", Material = "Material",
      Herkunft = "Herkunft", Provenienz = "Provenienz", Datierung = "Datierung",
      Erhaltungszustand = "Erhaltungszustand", Name_des_Statueninhabers = "Statueninhaber")
    shiny::tags$section(class = "object-summary",
      shiny::tags$h2(label_value(field(x, "Statue"))),
      lapply(names(props), function(k) meta_row(props[[k]], field(x, k))))
  })
  object_figures <- shiny::reactive({
    figure_data[figure_data$object_id == input$object_pick, , drop = FALSE]
  })
  shiny::observeEvent(input$object_pick, {
    shiny::updateNumericInput(session, "object_page", value = 1)
  }, ignoreInit = TRUE)
  output$object_page_label <- shiny::renderUI(shiny::tags$span(class = "help-note", paste(
    "von", max(1L, ceiling(nrow(object_figures()) / nv_settings$object_page_size)), "Seiten")))
  output$object_figure_table <- shiny::renderUI({
    x <- paginate(object_figures(), input$object_page, as.integer(nv_settings$object_page_size))
    if (!nrow(x)) return(shiny::p("Keine Figuren für dieses Objekt dokumentiert."))
    cols <- c(figure_id = "Figur-ID", side = "Objektseite", Register = "Register",
      Bildfeld = "Bildfeld", Gottheit = "Gottheit", Szene = "Szene")
    shiny::tagList(
      html_table(x, cols),
      shiny::tags$div(class = "object-figure-strip", lapply(seq_len(nrow(x)), function(i) {
        shiny::tags$div(class = "object-thumb",
          shiny::tags$div(class = "drawing-frame", fig_tag(x$figure_id[[i]], small = TRUE)),
          shiny::tags$span(label_value(x$Gottheit[[i]], "Unbestimmt")))
      }))
    )
  })
  output$object_text_table <- shiny::renderUI({
    x <- text_data[text_data$object_id == input$object_pick, , drop = FALSE]
    if (!nrow(x)) return(shiny::p("Keine Texte erfasst."))
    cols <- c(Textart = "Textart", "Position (grob)" = "Position (grob)",
      "Position (genau)" = "Position (genau)", Literatur = "Literatur")
    html_table(x, cols)
  })
  output$object_measurement_table <- shiny::renderUI({
    x <- measurement_data[measurement_data$object_id == input$object_pick, , drop = FALSE]
    if (!nrow(x)) return(shiny::p("Keine Maßangaben erfasst."))
    html_table(x, c(Hoehe = "Höhe", Breite = "Breite", Tiefe = "Tiefe",
      Masse_Bemerkung = "Bemerkung"))
  })

  output$matrix_table <- shiny::renderUI({
    relevant <- figure_data[!is.na(figure_data$Gottheit) &
      nzchar(figure_data$Gottheit) & figure_data$Gottheit != "zerstört", , drop = FALSE]
    if (!nrow(relevant)) return(shiny::p("Keine Gottheitsnamen erfasst."))
    popularity <- sort(table(relevant$Gottheit), decreasing = TRUE)
    deities <- utils::head(names(popularity), as.integer(input$matrix_n))
    objects <- object_data$object_id
    counts <- table(factor(relevant$Gottheit, levels = deities),
      factor(relevant$object_id, levels = objects))
    headings <- c(list(shiny::tags$th("Gottheit")),
      lapply(object_data$Statue, function(s) shiny::tags$th(class = "matrix-header", s)))
    rows <- lapply(seq_along(deities), function(i) {
      cells <- lapply(seq_along(objects), function(j) {
        n <- counts[i, j]
        yes <- n > 0
        shiny::tags$td(class = if (yes) "matrix-present" else "matrix-empty",
          title = if (yes) paste(n, "Einträge") else "Nicht dokumentiert",
          if (identical(input$matrix_mode, "count") && yes) as.character(n)
          else if (yes) "●" else "—")
      })
      do.call(shiny::tags$tr, c(list(shiny::tags$th(deities[[i]])), cells))
    })
    shiny::tags$div(class = "matrix-scroll",
      shiny::tags$table(class = "matrix-table",
        shiny::tags$thead(do.call(shiny::tags$tr, headings)),
        shiny::tags$tbody(rows)))
  })

  output$quality_metrics <- shiny::renderUI({
    n_imgs <- sum(vapply(figure_data$figure_id, has_image, logical(1)))
    known <- sum(!is.na(figure_data$Gottheit) &
      figure_data$Gottheit != "zerstört" & nzchar(figure_data$Gottheit), na.rm = TRUE)
    metrics <- c(Objekte = nrow(object_data), Figuren = nrow(figure_data),
      `Benannte Figuren` = known,
      `Ohne Gottesnamen` = sum(is.na(figure_data$Gottheit)),
      `Bilddateien vorhanden` = n_imgs,
      Textdatensätze = nrow(text_data))
    shiny::tags$div(class = "metric-grid", lapply(names(metrics), function(n) {
      shiny::tags$div(class = "metric-box", shiny::tags$span(n),
        shiny::tags$strong(count_format(metrics[[n]])))
    }))
  })
  output$deity_frequencies <- shiny::renderPlot({
    deities <- figure_data$Gottheit
    deities <- deities[!is.na(deities) & nzchar(deities) & deities != "zerstört"]
    if (!length(deities)) return(invisible(NULL))
    top <- utils::head(sort(table(deities), decreasing = TRUE), 12L)
    graphics::par(mar = c(4, 13, 2, 1))
    graphics::barplot(rev(top), horiz = TRUE, las = 1,
      col = "#344d5b", border = NA, cex.names = .83,
      xlab = "Anzahl dokumentierter Figuren")
  }, res = 96)
  output$missing_images_table <- shiny::renderUI({
    without <- figure_data[!vapply(figure_data$figure_id, has_image, logical(1)), , drop = FALSE]
    shiny::tagList(shiny::tags$p(count_format(nrow(without)), " Figuren ohne Bildverknüpfung"),
      html_table(utils::head(without, 40), c(figure_id = "Figur-ID", Statue = "Objekt",
        Bildfeld = "Bildfeld", Gottheit = "Gottheit")),
      shiny::p(class = "help-note", "Die Tabelle zeigt die ersten 40 Einträge. Alle Datensätze sind im Figurenkatalog verfügbar."))
  })
  output$unrepresented_objects_table <- shiny::renderUI({
    x <- object_data[!object_data$object_id %in% figure_data$object_id, , drop = FALSE]
    if (!nrow(x)) return(shiny::p("Alle Objekte haben Figureneinträge."))
    html_table(x, c(object_id = "Objekt-ID", Statue = "Objekt",
      Statue_Art = "Objekttyp", Standort = "Standort"))
  })
  output$unassigned_measurements_table <- shiny::renderUI({
    x <- measurement_data[!measurement_data$object_id %in% object_data$object_id,
      , drop = FALSE]
    if (!nrow(x)) return(shiny::p("Alle Maßdatensätze sind zugeordnet."))
    shiny::tagList(shiny::p(count_format(nrow(x)), " Einträge mit unbekannter Objektkennung."),
      html_table(x, c(measurement_id = "Maß-ID", object_id = "Objekt-ID",
        Hoehe = "Höhe", Breite = "Breite", Tiefe = "Tiefe")))
  })
}

shiny::shinyApp(ui, server)
