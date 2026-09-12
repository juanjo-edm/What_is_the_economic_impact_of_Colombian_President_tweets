#!/usr/bin/env Rscript

# Compare the existing petrogustavo_full.csv with a newly downloaded archive
# and merge them only when there are no repeated tweet IDs.

repo_root_from_script <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]

  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = FALSE)
    candidate <- normalizePath(file.path(dirname(script_path), "..", ".."), mustWork = FALSE)
    if (dir.exists(file.path(candidate, "scripts", "data")) &&
        dir.exists(file.path(candidate, "data", "raw"))) {
      return(candidate)
    }
  }

  cwd <- normalizePath(getwd(), mustWork = TRUE)
  if (dir.exists(file.path(cwd, "scripts", "data")) &&
      dir.exists(file.path(cwd, "data", "raw"))) {
    return(cwd)
  }

  stop(
    "No se encontro la raiz del repositorio. Ejecute este script desde la raiz o conserve su ubicacion en scripts/data/.",
    call. = FALSE
  )
}

read_tweet_csv <- function(path) {
  if (!file.exists(path)) {
    stop("No existe el archivo requerido: ", path, call. = FALSE)
  }

  if (requireNamespace("readr", quietly = TRUE)) {
    data <- readr::read_csv(
      path,
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE,
      progress = FALSE
    )
    data <- as.data.frame(data, stringsAsFactors = FALSE)
  } else {
    data <- utils::read.csv(
      path,
      colClasses = "character",
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }

  unnamed_cols <- is.na(names(data)) | names(data) == ""
  if (any(unnamed_cols)) {
    data <- data[, !unnamed_cols, drop = FALSE]
  }

  if (!"id" %in% names(data)) {
    stop("El archivo no tiene columna id: ", path, call. = FALSE)
  }

  data$id <- as.character(data$id)
  data
}

write_tweet_csv <- function(data, path) {
  if (requireNamespace("readr", quietly = TRUE)) {
    readr::write_csv(data, path, na = "")
  } else {
    utils::write.csv(
      data,
      path,
      row.names = FALSE,
      fileEncoding = "UTF-8",
      na = ""
    )
  }
}

non_empty_ids <- function(data) {
  ids <- as.character(data$id)
  ids[!is.na(ids) & nzchar(ids)]
}

duplicate_ids <- function(data) {
  ids <- non_empty_ids(data)
  unique(ids[duplicated(ids)])
}

align_columns <- function(data, columns) {
  missing_cols <- setdiff(columns, names(data))
  for (col in missing_cols) {
    data[[col]] <- NA_character_
  }
  data[, columns, drop = FALSE]
}

parse_created_at <- function(value) {
  parsed <- lapply(value, function(item) {
    if (is.na(item) || !nzchar(item)) {
      return(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"))
    }

    suppressWarnings(
      as.POSIXct(
        item,
        tz = "UTC",
        tryFormats = c("%Y-%m-%dT%H:%M:%OSZ", "%Y-%m-%d %H:%M:%S")
      )
    )
  })

  do.call(c, parsed)
}

repo_dir <- repo_root_from_script()
presidente_dir <- file.path(repo_dir, "data", "raw", "twitter", "Tweets de Gustavo Petro")
full_path <- file.path(presidente_dir, "petrogustavo_full.csv")
archive_path <- file.path(presidente_dir, "twitter_archive", "petrogustavo_archive.csv")
report_path <- file.path(presidente_dir, "twitter_archive", "petrogustavo_archive_merge_report.csv")

full_data <- read_tweet_csv(full_path)
archive_data <- read_tweet_csv(archive_path)

full_ids <- non_empty_ids(full_data)
archive_ids <- non_empty_ids(archive_data)

full_duplicate_ids <- duplicate_ids(full_data)
archive_duplicate_ids <- duplicate_ids(archive_data)
overlap_ids <- intersect(full_ids, archive_ids)

report <- data.frame(
  metric = c(
    "full_rows",
    "archive_rows",
    "full_non_empty_ids",
    "archive_non_empty_ids",
    "full_duplicate_ids",
    "archive_duplicate_ids",
    "overlap_ids"
  ),
  value = c(
    nrow(full_data),
    nrow(archive_data),
    length(full_ids),
    length(archive_ids),
    length(full_duplicate_ids),
    length(archive_duplicate_ids),
    length(overlap_ids)
  ),
  stringsAsFactors = FALSE
)

write_tweet_csv(report, report_path)

message("Comparacion completada:")
message("  Full rows: ", nrow(full_data))
message("  Archive rows: ", nrow(archive_data))
message("  IDs repetidos dentro de full: ", length(full_duplicate_ids))
message("  IDs repetidos dentro de archive: ", length(archive_duplicate_ids))
message("  IDs repetidos entre archivos: ", length(overlap_ids))
message("  Reporte: ", report_path)

if (length(full_duplicate_ids) > 0 ||
    length(archive_duplicate_ids) > 0 ||
    length(overlap_ids) > 0) {
  message("No se fusiono petrogustavo_full.csv porque hay IDs repetidos.")
  quit(status = 0)
}

columns <- unique(c(names(full_data), names(archive_data)))
merged_data <- rbind(
  align_columns(full_data, columns),
  align_columns(archive_data, columns)
)

if ("created_at" %in% names(merged_data)) {
  created_at <- parse_created_at(merged_data$created_at)
  order_index <- order(created_at, decreasing = TRUE, na.last = TRUE)
  merged_data <- merged_data[order_index, , drop = FALSE]
}

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
backup_path <- file.path(
  presidente_dir,
  paste0("petrogustavo_full_backup_", timestamp, ".csv")
)
temp_path <- paste0(full_path, ".tmp")

if (!file.copy(full_path, backup_path, overwrite = FALSE)) {
  stop("No se pudo crear backup antes de fusionar: ", backup_path, call. = FALSE)
}

write_tweet_csv(merged_data, temp_path)

if (!file.rename(temp_path, full_path)) {
  stop("No se pudo reemplazar petrogustavo_full.csv con el archivo fusionado.", call. = FALSE)
}

message("Fusion completada sin IDs repetidos.")
message("  Nuevo petrogustavo_full.csv rows: ", nrow(merged_data))
message("  Backup: ", backup_path)
