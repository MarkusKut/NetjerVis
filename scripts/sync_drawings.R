# Copy original drawings into www/ so BOTH Shiny and static Quarto can serve them.
# Run from the Quarto project root. Never changes the source SVG files.
# Every import/re-render and every Shiny startup runs this script.

if (!file.exists("R/data_config.R")) {
  stop("Run scripts/sync_drawings.R from the Quarto project root.")
}
if (!requireNamespace("readr", quietly = TRUE)) {
  stop("Install the readr package first.")
}

manifest_path <- "data/drawings_manifest.csv"
if (!file.exists(manifest_path)) stop("Drawing manifest not found: ", manifest_path)
manifest <- readr::read_csv(
  manifest_path,
  col_types = readr::cols(.default = readr::col_character()),
  show_col_types = FALSE,
  na = c("", "NA")
)
if (!all(c("figure_id", "file") %in% names(manifest))) {
  stop("Drawing manifest must contain figure_id and file columns.")
}

web_dir <- file.path("www", "drawings", "generated")
dir.create(web_dir, recursive = TRUE, showWarnings = FALSE)
web_table <- data.frame(
  figure_id = manifest$figure_id,
  source_file = manifest$file,
  public_url = rep(NA_character_, nrow(manifest)),
  status = rep("not_linked", nrow(manifest)),
  stringsAsFactors = FALSE
)
used_files <- character()
failures <- character()

for (i in seq_len(nrow(manifest))) {
  src <- trimws(manifest$file[[i]])
  if (is.na(src) || !nzchar(src)) next
  src <- gsub("\\\\", "/", src)

  # Paths starting with "www/" or "drawings/" may already be web assets.
  in_www <- if (startsWith(src, "www/")) src else file.path("www", src)
  if ((startsWith(src, "www/") || startsWith(src, "drawings/")) && file.exists(in_www)) {
    web_table$public_url[[i]] <- sub("^www/", "", gsub("\\\\", "/", in_www))
    web_table$status[[i]] <- "ready"
    if (startsWith(web_table$public_url[[i]], "drawings/generated/")) {
      used_files <- c(used_files, normalizePath(in_www, winslash = "/", mustWork = TRUE))
    }
    next
  }

  # For paths such as ../../bilder/..., resolve from the project root.
  # Do not use the Excel workbook folder as the base.
  if (!file.exists(src) || dir.exists(src)) {
    web_table$status[[i]] <- "source_missing"
    failures <- c(failures, paste0(manifest$figure_id[[i]], ": ", src))
    next
  }

  extension <- tolower(tools::file_ext(src))
  if (!extension %in% c("svg", "png", "jpg", "jpeg", "webp", "gif")) {
    web_table$status[[i]] <- "unsupported_type"
    failures <- c(failures, paste0(manifest$figure_id[[i]], ": unsupported file type: ", src))
    next
  }

  # The row prefix guarantees that even identical source basenames cannot collide.
  safe_name <- gsub("[^A-Za-z0-9._-]", "_", basename(src))
  target_name <- sprintf("%06d_%s", i, safe_name)
  dest <- file.path(web_dir, target_name)
  needs_copy <- !file.exists(dest)
  if (!needs_copy) {
    checksums <- tryCatch(tools::md5sum(c(src, dest)), error = function(e) c(NA, NA))
    needs_copy <- anyNA(checksums) || !identical(unname(checksums[[1]]), unname(checksums[[2]]))
  }
  if (needs_copy && !isTRUE(file.copy(src, dest, overwrite = TRUE))) {
    web_table$status[[i]] <- "copy_failed"
    failures <- c(failures, paste0(manifest$figure_id[[i]], ": cannot copy: ", src))
    next
  }
  web_table$public_url[[i]] <- paste0("drawings/generated/", target_name)
  web_table$status[[i]] <- "ready"
  used_files <- c(used_files, normalizePath(dest, winslash = "/", mustWork = TRUE))
}

# Remove old staging copies only. Never remove any original drawings.
old_files <- list.files(web_dir, full.names = TRUE, recursive = FALSE)
old_files <- old_files[!dir.exists(old_files)]
old_files_abs <- normalizePath(old_files, winslash = "/", mustWork = FALSE)
stale <- old_files[!old_files_abs %in% used_files]
if (length(stale)) unlink(stale)

readr::write_csv(web_table, "data/drawings_web.csv", na = "")
message("Drawings: ", sum(web_table$status == "ready"), " ready / ",
        sum(!is.na(web_table$source_file)), " linked in manifest.")
if (length(failures)) {
  warning(length(failures), " image source(s) could not be prepared. First entries:\n",
          paste(utils::head(failures, 5), collapse = "\n"), call. = FALSE)
}
