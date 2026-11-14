# NetjerVis – native R/Shiny + Shinylive + Quarto

This project is based on the NetjerVis files provided in this conversation. It replaces the **handwritten** `netjervis.js` browser application with an R Shiny application exported by Shinylive. All six research views are implemented in R. Quarto supplies the website, navigation, academic object pages, introduction, methodology and legal pages.

**Runtime status:** The R/Quarto/Shinylive export cannot be executed in the environment where this archive was prepared. The source, CSV references and image paths have been checked, but a browser test of the actual WebAssembly app is required locally before publishing. The generated Shinylive runtime assets are **not included** in this archive; the first local build downloads them.

## What's inside

- `shinylive_app/app.R`: all interactive logic, written in R + Shiny.
- `shinylive_app/helpers.R`: reusable catalogue rendering and lookup functions, written in R.
- `R/ui_config.R`: edit labels, filters, catalogue columns, comparison fields and page sizes without editing the app.
- `shinylive_app/www/site.css`: edit gallery sizes, table appearance and colors (CSS only).
- `scripts/prepare_shinylive.R`: create **public-only** CSVs and copy the ready SVG files into the browser application. Nothing accesses your external Excel file at runtime.
- `scripts/generate_object_pages.R`: one Quarto page for each **object**, not each figure. Custom notes live in `objekte/_notes/` and are not overwritten.
- `scripts/build_site.R`: incremental export to `www/shinylive/` and build preparation.
- `datenbank.qmd`, `katalog.qmd`, `vergleiche.qmd`: Quarto pages embedding the Shinylive application.
- `data/`: prepared research tables; 1,005 figures, 15 objects, 173 text records, 56 measurement records in the supplied snapshot; six have object IDs not present in the 15-object table and are shown as a data-quality warning.
- `www/drawings/generated/` and `shinylive_app/www/drawings/generated/`: 95 ready SVGs included from the supplied files.
- `impressum.qmd` and `datenschutz.qmd`: editable previous drafts; **complete placeholders and review actual deployment before publishing**.

## 1. Installation on your Mac

Extract the archive and open `magical_statues_visual_db.Rproj` in RStudio. Check the Excel path in `R/data_config.R`. It currently points to the sibling `magical_statues_rsqlite_starter` project, as discussed earlier. If that workbook is inaccessible, the already prepared data in `data/` is used instead.

Install the R packages (once):

```r
install.packages(c(
  "shiny", "bslib", "shinylive",
  "readxl", "readr", "dplyr", "tibble", "DBI", "RSQLite"
))
```

Quarto must also be installed (available at https://quarto.org/docs/get-started/).

## 2. Preview the native R app locally

In the RStudio Console, run:

```r
source("scripts/run_shiny_locally.R")
```

This reads the latest Excel file when available, prepares browser-safe CSV data, updates ready SVGs and runs **the same `shinylive_app/app.R`** on your local Shiny server. Use this to check the tabs and filters before exporting Shinylive.

## 3. Build for GitHub Pages

From the **RStudio Terminal** at the project root:

```bash
quarto render
```

The pre-render script (`scripts/build_site.R`) performs, in order:

1. Re-import your Excel workbook if changed; otherwise retain prepared CSVs.
2. Synchronize original SVGs when their paths are accessible locally.
3. Regenerate object pages while preserving `objekte/_notes/`.
4. Copy **only publication-ready** CSV columns and SVG drawings into `shinylive_app/`.
5. Run `shinylive::export()` to generate a self-contained browser application at `www/shinylive/` **only when inputs changed**.
6. Quarto then builds the site into `docs/`.

The first export downloads the Shinylive/webR runtime. It may be larger and slower than the earlier JavaScript-only site. Subsequent builds reuse the output if the inputs are identical.

Check the site with:

```bash
quarto preview
```

**Do not open `docs/index.html` via `file://`** to test Shinylive; use a local HTTP server (such as `quarto preview`), because browser modules and WebAssembly need normal site serving.

## 4. Publish on GitHub Pages

For the existing `NetjerVis` repository, configure GitHub Pages to deploy from the `main` branch and the `/docs` folder, then commit/push both source files and `docs/` after rendering:

```bash
git add .
git commit -m "Publish NetjerVis Shiny for R through Shinylive"
git push
```

A GitHub Actions workflow can be configured later, but it will need access to the prepared data and cannot read your private iCloud workbook or original `../../bilder` files. Build locally first.

## 5. What you can edit without JavaScript

| File | Control |
| --- | --- |
| `R/ui_config.R` | Filters, labels, comparison fields, pagination and columns |
| `shinylive_app/app.R` | New reactive functions, statistics, UI in native R |
| `shinylive_app/helpers.R` | Figure cards, tables, image logic in native R |
| `shinylive_app/www/site.css` | Layout, spacing, SVG heights and colors |
| `index.qmd`, `methodik.qmd`, `objekte/_notes/*.md` | Academic content |
| `R/data_config.R`, `scripts/*.R` | Workbook paths, normalization, import and publishing |

The browser still uses Shiny/Shinylive's JavaScript runtime internally. No handwritten JS application file is required.

## 6. Boundaries and important caveats

- The published application is read-only. Excel changes require another local render and push.
- `shiny::downloadHandler()` is included, but **confirm browser download functionality** in exported Shinylive before relying on it.
- Standalone Shinylive uses a browser-based R runtime; first load can be noticeably slower than the custom JavaScript catalogue.
- Image scaling on screen is not archaeological size normalization.
- Empty occurrence-matrix cells mean **not documented**, not historically absent.
- The current `figure_id` identifiers derive from the source table and may change if `id.2` changes. A future stable mapping is recommended before extending the corpus.
- Object notes (`objekte/_notes/`) are the place for custom annotations; the generated `objekte/Heilstatue__*.qmd` files are replaced during rebuilds.
- Browser clients must support WebAssembly; some privacy/ad-blocking setups may interfere with first load.
- The source repository can contain paths in `data/drawings_manifest.csv`; the **published browser app** explicitly excludes those paths. Review repository contents if the GitHub repository is public.

## 7. Technical validation

The included CSVs, entity relations, SVG copy paths and absence of custom JS files were checked programmatically. R package installation, the actual Shinylive export and a full Quarto browser run **could not be performed here** because R and Quarto executables are unavailable.

Official references:

- https://posit-dev.github.io/r-shinylive/reference/export.html
- https://rstudio.github.io/bslib/reference/sidebar.html
- https://quarto.org/docs/publishing/github-pages.html
