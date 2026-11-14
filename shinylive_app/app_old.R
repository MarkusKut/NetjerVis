# Visual research catalogue: run from RStudio or shiny::runApp("app.R")
# This is deliberately one application, not a page for each figure.
library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(htmltools)
source("R/site_helpers.R", local = TRUE)

fig <- figure_data
obj <- object_data
all_figure_ids <- fig$figure_id
figure_choice_text <- paste0(
  ifelse(is.na(fig$Gottheit), "nicht bestimmt", fig$Gottheit), " · ",
  fig$Statue, " · ", fig$Position, " · Reg. ", fig$Register, " · St. ", fig$Stelle, " · #", fig$`id.2`
)
figure_choices <- stats::setNames(fig$figure_id, figure_choice_text)
object_group_choices <- stats::setNames(obj$object_group, obj$object_group)
object_choices <- stats::setNames(obj$object_id, obj$Statue)
options_for <- function(field) c("Alle"="__ALL__", sort(unique(stats::na.omit(fig[[field]]))))




show_pair <- function(label, val) {
  tags$div(class = "meta-pair", tags$span(class = "meta-label", label),
           tags$span(class = "meta-value", nonempty(val)))
}

figure_card <- function(f, compact = FALSE) {
  id <- f$figure_id[[1]]
  tagList(
    tags$div(class = if (compact) "mini-figure-card" else "full-figure-card",
      tags$div(class = "drawing-frame", figure_image_tag(id)),
      tags$div(class = "figure-card-info",
        tags$div(class = "figure-ref", id),
        tags$h4(nonempty(f$Gottheit[[1]], "Gottheit nicht bestimmt")),
        tags$p(class = "small-note", nonempty(paste(stats::na.omit(unlist(f[1, paste0("Epitheton", 1:5), drop=FALSE], use.names = FALSE)), collapse=" · "), "")),
        tags$p(f$Statue[[1]]),
        tags$p(class = "small-note", paste(nonempty(f$Position[[1]]), "· Reg. ", nonempty(f$Register[[1]]), "· St.", nonempty(f$Stelle[[1]]))),
        if (!compact) tagList(
          show_pair("Körper", f$Koerper[[1]]),
          show_pair("Kopf", f$Kopf[[1]]),
          show_pair("Kopfschmuck", f$Kopfschmuck[[1]]),
          show_pair("Haltung", f$Haltung[[1]]),
          show_pair("Objekte in Händen", f$Objekte_in_Haenden[[1]]),
          show_pair("Szene", f$Szene[[1]]),
          show_pair("Inschrift", f$Inschrift[[1]]),
          show_pair("Weitere Beischrift", f$Text_vor_Gott[1]),
          show_pair("Literatur", f$Literatur[[1]]),
         # show_pair("Bemerkungen", f$Bemerkungen[[1]])
        )
      )
    )
  )
}


ui <- fluidPage(
  
  theme = bslib::bs_theme(version=5, bootswatch="flatly", bg="#fbfaf7", fg="#273740", primary="#344d5b"),
  
  tags$head(
    tags$link(rel="stylesheet", type="text/css", href="site.css"),
    tags$style(HTML("\n
                    .app-heading{margin:18px 0 4px 0;font-weight:650;}
                    .app-subtitle{margin:0 0 22px 0;color:#65747c;}\n
                    .well{background:#fff;border:1px solid #dce1e3;border-radius:10px;box-shadow:none;}\n
                    .nav-tabs{margin:0 0 16px 0;}
                    .figure-grid,.compare-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(225px,1fr));gap:14px;}\n
                    .mini-figure-card,.full-figure-card{background:#fff;border:1px solid #dce1e3;border-radius:10px;overflow:hidden;min-width:0;}\n
                    .drawing-frame{height:210px;display:grid;place-items:center;padding:12px;background:#f5f4f0;border-bottom:1px solid #e7e9e8;text-align:center;}\n
                    .drawing-frame .figure-img{height:190px;}
                    .figure-card-info{padding:12px;}
                    .figure-card-info h4{font-size:1.14rem;margin:5px 0;}\n
                    .figure-card-info p{margin-bottom:6px;} .figure-ref,
                    .small-note{font-size:.78rem;color:#65747c;word-break:break-all;}\n
                    .meta-pair{display:flex;flex-wrap:wrap;gap:8px;align-items:baseline;border-bottom:1px solid #efefed;padding:4px 0;font-size:.86rem;}\n
                    .meta-label{width:115px;flex:0 0 115px;color:#65747c;} .meta-value{flex:1;overflow-wrap:anywhere;}\n
                    .metric-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin:16px 0;}\n
                    .metric{padding:16px;background:white;border:1px solid #dce1e3;border-radius:10px;}
                    .metric strong{display:block;font-size:1.7rem;}\n
                    .caution{font-size:.87rem;color:#665b49;border-left:3px solid #b18b57;padding:8px 12px;margin:12px 0;background:#f7f5ef;}\n
                    .figure-detail{margin-top:16px;} .quality-list li{margin-bottom:6px;}\n    "))
  ),
  
  h1(class="app-heading", "NetjerVis"),
  
  p(class="app-subtitle", "Ikonographie und Darstellungen antiker ägyptischer Götter von 400 - 250 v. u. Z."),
  
  sidebarLayout(
    sidebarPanel(width=3,
      h4("Recherchefilter"),
      selectInput("object_group_filter", "Objektgruppe", choices=c("Alle Objekte"="__ALL__", object_group_choices)),
      selectInput("object_filter", "Objekt", choices=c("Alle Objekte"="__ALL__", object_choices)),
      selectizeInput("deity_filter", "Gottheit", choices=options_for("Gottheit"), selected="__ALL__"),
      selectInput("side_filter", "Objektseite", choices=options_for("side")),
      selectizeInput("body_filter", "Körper", choices=options_for("Koerper"), selected="__ALL__"),
      selectizeInput("head_filter", "Kopf", choices=options_for("Kopf"), selected="__ALL__"),
      selectizeInput("crown_filter", "Kopfschmuck", choices=options_for("Kopfschmuck"), selected="__ALL__"),
      selectizeInput("posture_filter", "Haltung", choices=options_for("Haltung"), selected="__ALL__"),
      textInput("term", "Freitextsuche", placeholder="Szene, Epitheton, Literatur ..."),
      checkboxInput("with_drawings", "Nur vorhandene Bilddateien", value=FALSE),
      actionButton("clear", "Filter zurücksetzen", class="btn-outline-secondary"),
      hr(),
      p(class="small-note", "Die Filter betreffen den Figurenkatalog und die Galerie. Andere Ansichten haben eigene Auswahlfelder.")
    ),
    mainPanel(width=9,
      tabsetPanel(id="tabs",
        tabPanel("Figurenkatalog", value="catalogue",
          uiOutput("count_text"),
          downloadButton("download_filtered", "Gefilterte Daten als CSV"),
          DTOutput("figure_table"),
          div(class="figure-detail", h3("Datenblatt der markierten Figur"), uiOutput("figure_detail"),
              actionButton("add_compare", "Zum Vergleich hinzufügen"))
        ),
        tabPanel("Zeichnungsgalerie", value="gallery",
          p("Visuelle Übersicht der ersten 48 passenden Figuren. Suchfilter links verengen die Auswahl."),
          uiOutput("gallery")
        ),
        tabPanel("Figurenvergleich", value="compare",
          p("Zwei bis vier Darstellungen direkt nebeneinander betrachten. Die Darstellung in derselben Bildschirmhöhe ist keine Maßstabsprüfung."),
          selectizeInput("selected_figures", "Vergleichsfiguren", choices=figure_choices,
                         selected=utils::head(all_figure_ids, 2), multiple=TRUE,
                         options=list(maxItems=4, placeholder="Figuren wählen ...")),
          uiOutput("compare_cards"),
          h4("Merkmalsmatrix"),
          tableOutput("compare_table"),
          div(class="caution", "Vergleichbarkeit der SVG-Skalierung ist erst nach dokumentierter Normalisierung an der Registerhöhe gegeben.")
        ),
        tabPanel("Statuendatenblatt", value="object",
          selectInput("statue_select", "Statue", choices=object_choices,
                      selected=obj$object_id[[1]]),
          uiOutput("object_overview"),
          h4("Figuren"), DTOutput("object_figures"),
          h4("Texte"), DTOutput("object_texts")
        ),
        tabPanel("Vorkommensmatrix", value="matrix",
          selectInput("matrix_n", "Häufigste Gottheitsnamen", choices=c(15,25,40), selected=25),
          plotOutput("matrix_plot", height="690px"),
          div(class="caution", "Ein leeres Feld bedeutet 'nicht dokumentiert', nicht 'nachgewiesen abwesend'. Der Erhaltungszustand variiert zwischen den Objekten.")
        ),
        tabPanel("Datenqualität", value="quality",
          uiOutput("quality_metrics"),
          h4("Fehlende Bildverknüpfungen"),
          DTOutput("missing_images"),
          h4("Objekte ohne Figureneinträge"),
          DTOutput("missing_objects")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  filtered <- reactive({
    x <- fig
    checks <- c(
      object_group="object_group_filter",
      object_id="object_filter", 
      Gottheit="deity_filter", 
      side="side_filter",
      oerper="body_filter",
      Kopf="head_filter",
      Kopfschmuck="crown_filter",
      Haltung="posture_filter")
    for (field in names(checks)) {
      choice <- input[[checks[[field]]]]
      if (!is.null(choice) && length(choice) == 1 && choice != "__ALL__") {
        x <- x[!is.na(x[[field]]) & x[[field]] == choice, , drop=FALSE]
      }
    }
    if (nzchar(trimws(input$term %||% ""))) {
      columns <- c("Gottheit", "Szene", "Position", "Epitheton1", "Epitheton2",
                   "Koerper", "Kopf", "Kopfschmuck", "Literatur", "Bemerkungen")
      combined <- apply(as.matrix(x[, columns, drop=FALSE]), 1,
                        function(v) paste(v[!is.na(v)], collapse=" "))
      x <- x[grepl(tolower(trimws(input$term)), tolower(combined), fixed=TRUE), , drop=FALSE]
    }
    if (isTRUE(input$with_drawings) && nrow(x)) {
      x <- x[vapply(x$figure_id, function(id) !is.null(figure_media(id)), logical(1)), , drop=FALSE]
    }
    x
  })
  `%||%` <- function(a, b) if (is.null(a)) b else a
  observeEvent(input$clear, {
    updateSelectInput(session, "object_filter", selected="__ALL__")
    updateSelectizeInput(session, "deity_filter", selected="__ALL__")
    updateSelectInput(session, "side_filter", selected="__ALL__")
    updateSelectizeInput(session, "body_filter", selected="__ALL__")
    updateSelectizeInput(session, "head_filter", selected="__ALL__")
    updateSelectizeInput(session, "crown_filter", selected="__ALL__")
    updateSelectizeInput(session, "posture_filter", selected="__ALL__")
    updateTextInput(session, "term", value="")
    updateCheckboxInput(session, "with_drawings", value=FALSE)
  })
  output$count_text <- renderUI({
    tags$p(tags$strong(format(nrow(filtered()), big.mark=".")),
           "von", format(nrow(fig), big.mark="."), "Figurenzeilen angezeigt")
  })
  output$figure_table <- DT::renderDT({
    x <- filtered()
    x <- x[, c("figure_id", "Statue", "side", "Register", "Bildfeld", "Gottheit",
                "Haltung", "Koerper", "Kopf", "Kopfschmuck", "Szene"), drop=FALSE]
    DT::datatable(x, rownames=FALSE, selection="single", filter="top",
                  options=list(pageLength=12, scrollX=TRUE, autoWidth=TRUE))
  }, server=FALSE)
  chosen_figure <- reactive({
    d <- filtered(); if (!nrow(d)) return(NULL)
    idx <- input$figure_table_rows_selected
    if (length(idx) != 1 || idx < 1 || idx > nrow(d)) idx <- 1
    d[idx, , drop=FALSE]
  })
  output$figure_detail <- renderUI({
    f <- chosen_figure()
    if (is.null(f)) return(tags$p("Keine passenden Einträge"))
    tags$div(class="compare-grid", style="grid-template-columns:minmax(220px,340px);", figure_card(f))
  })
  observeEvent(input$add_compare, {
    f <- chosen_figure(); if (is.null(f)) return()
    selected <- unique(c(input$selected_figures, f$figure_id[[1]]))
    updateSelectizeInput(session, "selected_figures", selected=utils::tail(selected, 4))
    updateTabsetPanel(session, "tabs", selected="compare")
  })
  output$gallery <- renderUI({
    x <- utils::head(filtered(), 48)
    if (!nrow(x)) return(tags$p("Keine passenden Figuren"))
    tags$div(class="figure-grid",
      lapply(seq_len(nrow(x)), function(i) figure_card(x[i, , drop=FALSE], compact=TRUE)))
  })
  chosen_comparison <- reactive({
    ids <- utils::head(input$selected_figures, 4)
    f <- fig[match(ids, fig$figure_id), , drop=FALSE]
    f[!is.na(f$figure_id), , drop=FALSE]
  })
  output$compare_cards <- renderUI({
    f <- chosen_comparison()
    if (!nrow(f)) return(tags$p("Bitte Figuren auswählen"))
    tags$div(class="compare-grid", lapply(seq_len(nrow(f)), function(i) figure_card(f[i, , drop=FALSE])))
  })
  output$compare_table <- renderTable({
    f <- chosen_comparison()
    if (!nrow(f)) return(NULL)
    attrs <- c("Gottheit", "Geschlecht", "Haltung", "Koerper", "Kopf", "Kopfschmuck", "Handhaltung", "Objekte_in_Haenden", "Szene", "Register", "Bildfeld")
    v <- lapply(seq_len(nrow(f)), function(i) vapply(attrs, function(a) nonempty(f[[a]][[i]]), character(1)))
    result <- data.frame(Merkmal=attrs, do.call(cbind, v), check.names=FALSE)
    names(result)[-1] <- paste0("Figur ", seq_len(nrow(f)))
    result
  }, striped=TRUE, bordered=TRUE, spacing="s")
  output$object_overview <- renderUI({
    statue_overview(input$statue_select)
  })
  output$object_figures <- DT::renderDT({
    f <- fig[fig$object_id == input$statue_select, , drop=FALSE]
    f$Zeichnung <- vapply(f$figure_id, function(id) {
      as.character(figure_image_tag(id, static = FALSE, small = TRUE))
    }, character(1))
    view <- f[, c("Zeichnung", "figure_id", "side", "Register", "Bildfeld", "Gottheit", "Szene"), drop=FALSE]
    DT::datatable(view, rownames=FALSE,
                  escape=setdiff(seq_along(view), 1L),
                  options=list(pageLength=10, scrollX=TRUE))
  }, server=FALSE)
  output$object_texts <- DT::renderDT({
    t <- text_data[text_data$object_id == input$statue_select, , drop=FALSE]
    fields <- c("Textart", "Position (grob)", "Position (genau)", "Literatur")
    DT::datatable(t[, fields, drop=FALSE], rownames=FALSE,
                  options=list(pageLength=8, scrollX=TRUE))
  }, server=FALSE)
  output$matrix_plot <- renderPlot({
    f <- fig[!is.na(fig$Gottheit) & fig$Gottheit != "zerstört", , drop=FALSE]
    present <- unique(f[, c("object_id", "Gottheit")])
    freq <- sort(table(present$Gottheit), decreasing=TRUE)
    names_top <- utils::head(names(freq), as.integer(input$matrix_n))
    skeleton <- expand.grid(object_id=obj$object_id, Gottheit=names_top,
                            stringsAsFactors=FALSE)
    skeleton$key <- paste(skeleton$object_id, skeleton$Gottheit, sep="::")
    present$key <- paste(present$object_id, present$Gottheit, sep="::")
    skeleton$documented <- skeleton$key %in% present$key
    skeleton$object_name <- obj$Statue[match(skeleton$object_id, obj$object_id)]
    skeleton$object_name <- factor(skeleton$object_name, levels=rev(obj$Statue))
    skeleton$Gottheit <- factor(skeleton$Gottheit, levels=rev(names_top))
    ggplot(skeleton, aes(x=object_name, y=Gottheit, fill=documented)) +
      geom_tile(color="white", linewidth=0.25) +
      scale_fill_manual(values=c("FALSE"="#e9e8e3", "TRUE"="#344d5b"),
                        labels=c("FALSE"="nicht dokumentiert", "TRUE"="dokumentiert"),
                        name="Erfassung") +
      labs(x="Objekte", y="Gottheiten") +
      theme_minimal(base_size=10) +
      theme(axis.text.x=element_text(angle=65, hjust=1, size=8),
            panel.grid=element_blank(), legend.position="bottom")
  }, res=100)
  output$quality_metrics <- renderUI({
    missing_gods <- sum(is.na(fig$Gottheit))
    with_names <- sum(!is.na(fig$Gottheit) & fig$Gottheit != "zerstört")
    with_files <- sum(vapply(fig$figure_id, function(id) !is.null(figure_media(id)), logical(1)))
    with_links <- sum(!is.na(manifest_data$file))
    vals <- list("Objekte"=nrow(obj), "Figuren"=nrow(fig), "Benannte Figuren"=with_names,
                 "Ohne Gottesnamen"=missing_gods, "Bildverweise"=with_links, "Bilddateien vorhanden"=with_files)
    tags$div(class="metric-grid", lapply(names(vals), function(n) {
      tags$div(class="metric", tags$small(n), tags$strong(vals[[n]]))
    }))
  })
  output$missing_images <- DT::renderDT({
    absent <- !vapply(fig$figure_id, function(id) !is.null(figure_media(id)), logical(1))
    DT::datatable(fig[absent, c("figure_id", "Statue", "Bildfeld", "Gottheit")],
                  rownames=FALSE, options=list(pageLength=7, scrollX=TRUE))
  }, server=FALSE)
  output$missing_objects <- DT::renderDT({
    unrepresented <- obj[!obj$object_id %in% fig$object_id,
                         c("object_id", "Statue", "Statue_Art", "Standort"), drop=FALSE]
    DT::datatable(unrepresented, rownames=FALSE, options=list(pageLength=10, scrollX=TRUE))
  }, server=FALSE)
  output$download_filtered <- downloadHandler(
    filename=function() paste0("goetter_gefiltert_", Sys.Date(), ".csv"),
    content=function(file) readr::write_csv(filtered(), file, na="")
  )
}

shinyApp(ui, server)
