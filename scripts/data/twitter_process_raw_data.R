#!/usr/bin/env Rscript

# 1. Setup ----

## 1.0 Locale ----

set_utf8_locale <- function() {
  if (.Platform$OS.type != "windows") {
    return(invisible(Sys.getlocale("LC_CTYPE")))
  }

  candidates <- c(
    "Spanish_Colombia.UTF-8",
    "Spanish_Colombia.65001",
    "English_United States.UTF-8",
    ".UTF-8"
  )

  for (candidate in candidates) {
    result <- suppressWarnings(try(Sys.setlocale("LC_CTYPE", candidate), silent = TRUE))
    if (!inherits(result, "try-error") && !is.na(result)) {
      return(invisible(result))
    }
  }

  invisible(Sys.getlocale("LC_CTYPE"))
}

set_utf8_locale()

## 1.1 Librerias ----

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(tibble)

## 1.2 Rutas del proyecto ----

repo_root_from_script <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]

  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = FALSE)
    candidate <- normalizePath(file.path(dirname(script_path), "..", ".."), mustWork = FALSE)
    if (dir.exists(file.path(candidate, "scripts", "data")) &&
        dir.exists(file.path(candidate, "data", "raw")) &&
        dir.exists(file.path(candidate, "notebooks"))) {
      return(candidate)
    }
  }

  cwd <- normalizePath(getwd(), mustWork = TRUE)
  if (dir.exists(file.path(cwd, "scripts", "data")) &&
      dir.exists(file.path(cwd, "data", "raw")) &&
      dir.exists(file.path(cwd, "notebooks"))) {
    return(cwd)
  }

  stop(
    "No se encontro la raiz del repositorio. Ejecute este script desde la raiz o conserve su ubicacion en scripts/data/.",
    call. = FALSE
  )
}

repo_dir <- repo_root_from_script()
raw_twitter_opinion_dir <- file.path(repo_dir, "data", "raw", "twitter", "Opinión sobre Petro")
raw_twitter_presidente_dir <- file.path(repo_dir, "data", "raw", "twitter", "Tweets de Gustavo Petro")
raw_twitter_presidente_full_path <- file.path(raw_twitter_presidente_dir, "petrogustavo_full.csv")
raw_twitter_presidente_data_dir <- file.path(raw_twitter_presidente_dir, "twitter_data")
raw_twitter_presidente_archive_dir <- file.path(raw_twitter_presidente_dir, "twitter_archive")
raw_market_dir <- file.path(repo_dir, "data", "raw", "market")
processed_dir <- file.path(repo_dir, "data", "processed")

## 1.3 Parametros del script ----

date_start <- as.Date("2022-08-01")
date_end <- as.Date("2026-05-31")
presidential_date_start <- as.Date("2022-08-07")

corpus_label_opinion <- "Conversación pública sobre Gustavo Petro"
corpus_label_presidente <- "Tweets escritos por @petrogustavo"

financial_series <- c("trm", "colcap", "tes_1y", "tes_5y", "tes_10y")
market_series <- c(financial_series, "energy_spot_price")

## 1.4 Fuentes de mercado documentadas ----

trm_reference_url <- "https://www.banrep.gov.co/es/como-consultar-datos-historicos-tasa-representativa-mercado-trm-nuevo-portal-estadisticas"
colcap_reference_url <- "https://www.banrep.gov.co/en/node/50428"
tes_reference_url <- "https://www.banrep.gov.co/en/node/50444"
xm_daily_url <- "https://servapibi.xm.com.co/daily"

trm_series_id <- "1"
colcap_series_id <- "6"
tes_1y_series_id <- "15272"
tes_5y_series_id <- "15273"
tes_10y_series_id <- "15274"
energy_spot_price_metric_id <- "PPPrecBolsNaci"
energy_spot_price_series_name <- "Precio Bolsa Nacional Ponderado por Sistema"
energy_spot_price_units <- "COP/kWh"

## 1.5 Funciones auxiliares necesarias ----

write_csv_safe <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
  invisible(path)
}

read_csv_character <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE,
    lazy = FALSE
  )
}

# Reparar secuencias de acentuación mal serializadas presentes en el archivo
# presidencial legacy. Se aplica solo después de retirar URLs, para no modificar
# identificadores de enlaces que contienen secuencias similares.
repair_legacy_twitter_text <- function(x) {
  x |>
    stringr::str_replace_all("[cC]3", "ó") |>
    stringr::str_replace_all("[cC]-", "í") |>
    stringr::str_replace_all("[cC]!", "á") |>
    stringr::str_replace_all("[cC]\\)", "é") |>
    stringr::str_replace_all("[cC]1", "ñ") |>
    stringr::str_replace_all("[cC]:", "ú")
}

relative_to_repo <- function(path) {
  normalized_repo <- normalizePath(repo_dir, winslash = "/", mustWork = FALSE)
  normalized_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  repo_prefix <- paste0(normalized_repo, "/")

  if (startsWith(normalized_path, repo_prefix)) {
    substring(normalized_path, nchar(repo_prefix) + 1)
  } else {
    normalized_path
  }
}

empty_tweets <- function() {
  tibble::tibble(
    corpus = character(),
    corpus_label = character(),
    raw_source = character(),
    source_dir = character(),
    source_file = character(),
    id = character(),
    author_id = character(),
    created_at_raw = character(),
    created_at = as.POSIXct(character()),
    timestamp_utc = character(),
    timestamp_bogota = character(),
    date_bogota = as.Date(character()),
    date = as.Date(character()),
    text = character(),
    lang = character()
  )
}

read_tweet_files <- function(
  files,
  corpus,
  corpus_label,
  raw_source,
  start_date = date_start,
  end_date = date_end
) {
  if (length(files) == 0) {
    return(empty_tweets())
  }

  rows <- lapply(files, function(path) {
    raw <- read_csv_character(path)
    required_cols <- c("id", "author_id", "created_at", "text", "lang")
    missing_cols <- setdiff(required_cols, names(raw))

    if (length(missing_cols) > 0) {
      stop(
        "El archivo de tweets no tiene columnas requeridas: ",
        path,
        " (faltan: ",
        paste(missing_cols, collapse = ", "),
        ")",
        call. = FALSE
      )
    }

    parsed_time <- suppressWarnings(lubridate::ymd_hms(raw$created_at, tz = "UTC", quiet = TRUE))
    parsed_time_bogota <- lubridate::with_tz(parsed_time, tzone = "America/Bogota")

    tibble::tibble(
      corpus = corpus,
      corpus_label = corpus_label,
      raw_source = raw_source,
      source_dir = relative_to_repo(dirname(path)),
      source_file = basename(path),
      id = as.character(raw$id),
      author_id = as.character(raw$author_id),
      created_at_raw = as.character(raw$created_at),
      created_at = parsed_time,
      timestamp_utc = format(parsed_time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      timestamp_bogota = format(parsed_time_bogota, "%Y-%m-%dT%H:%M:%S%z", tz = "America/Bogota"),
      date_bogota = as.Date(parsed_time_bogota, tz = "America/Bogota"),
      date = as.Date(parsed_time_bogota, tz = "America/Bogota"),
      text = as.character(raw$text),
      lang = as.character(raw$lang)
    )
  })

  dplyr::bind_rows(rows) |>
    # Excluir textos con bytes de control no imprimibles que rompen su lectura
    # lingüística y convierten fragmentos codificados en tokens espurios.
    dplyr::filter(!stringr::str_detect(
      dplyr::coalesce(text, ""),
      "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]"
    )) |>
    dplyr::filter(!is.na(date_bogota), date_bogota >= start_date, date_bogota <= end_date) |>
    dplyr::arrange(corpus, date, created_at, id) |>
    dplyr::distinct(corpus, raw_source, id, .keep_all = TRUE)
}

read_market_raw_series <- function(series) {
  path <- file.path(raw_market_dir, paste0(series, "_raw.csv"))

  if (!file.exists(path)) {
    stop("Falta el archivo raw requerido para la serie ", series, ": ", path, call. = FALSE)
  }

  raw <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)

  if (!"date" %in% names(raw)) {
    stop("Falta columna date en ", path, call. = FALSE)
  }

  value_col <- if (series %in% names(raw)) {
    series
  } else {
    setdiff(names(raw), "date")[[1]]
  }

  tibble::tibble(
    date = as.Date(raw$date),
    value = suppressWarnings(as.numeric(raw[[value_col]]))
  ) |>
    dplyr::filter(!is.na(date)) |>
    dplyr::arrange(date) |>
    dplyr::group_by(date) |>
    dplyr::summarise(value = dplyr::last(value[!is.na(value)], default = NA_real_), .groups = "drop") |>
    dplyr::rename(!!series := value)
}

first_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[min(ok)]
}

last_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[max(ok)]
}

# 2. Carga de insumos ----

## 2.1 Validacion de rutas ----

required_dirs <- c(raw_twitter_opinion_dir, raw_twitter_presidente_dir, raw_market_dir)
missing_dirs <- required_dirs[!dir.exists(required_dirs)]

if (length(missing_dirs) > 0) {
  stop("Faltan carpetas raw requeridas: ", paste(missing_dirs, collapse = ", "), call. = FALSE)
}

if (!file.exists(raw_twitter_presidente_full_path) &&
    !dir.exists(raw_twitter_presidente_data_dir) &&
    !dir.exists(raw_twitter_presidente_archive_dir)) {
  stop(
    "No se encontro fuente presidencial. Debe existir petrogustavo_full.csv ",
    "o alguna carpeta fallback twitter_data/twitter_archive.",
    call. = FALSE
  )
}

dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

## 2.2 Archivos raw de Twitter ----

opinion_files <- list.files(
  raw_twitter_opinion_dir,
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = FALSE
)

presidente_full_files <- if (file.exists(raw_twitter_presidente_full_path)) {
  raw_twitter_presidente_full_path
} else {
  character()
}

presidente_data_files <- if (dir.exists(raw_twitter_presidente_data_dir)) {
  list.files(
    raw_twitter_presidente_data_dir,
    pattern = "\\.csv$",
    full.names = TRUE,
    recursive = FALSE
  )
} else {
  character()
}

presidente_archive_files <- if (dir.exists(raw_twitter_presidente_archive_dir)) {
  list.files(
    raw_twitter_presidente_archive_dir,
    pattern = "\\.csv$",
    full.names = TRUE,
    recursive = FALSE
  )
} else {
  character()
}

# 3. Normalizacion de Twitter ----

## 3.1 Corpus de opinion ----

tweets_opinion <- read_tweet_files(
  files = sort(opinion_files),
  corpus = "opinion",
  corpus_label = corpus_label_opinion,
  raw_source = "opinion",
  start_date = date_start,
  end_date = date_end
)

## 3.2 Corpus presidencial ----

tweets_presidente_full <- read_tweet_files(
  files = presidente_full_files,
  corpus = "presidente",
  corpus_label = corpus_label_presidente,
  raw_source = "petrogustavo_full",
  start_date = presidential_date_start,
  end_date = date_end
)

tweets_presidente_data <- read_tweet_files(
  files = sort(presidente_data_files),
  corpus = "presidente",
  corpus_label = corpus_label_presidente,
  raw_source = "twitter_data",
  start_date = presidential_date_start,
  end_date = date_end
)

tweets_presidente_archive <- read_tweet_files(
  files = sort(presidente_archive_files),
  corpus = "presidente",
  corpus_label = corpus_label_presidente,
  raw_source = "twitter_archive",
  start_date = presidential_date_start,
  end_date = date_end
)

tweets_presidente <- dplyr::bind_rows(
  tweets_presidente_full,
  tweets_presidente_data,
  tweets_presidente_archive
) |>
  dplyr::arrange(date, created_at, id) |>
  dplyr::distinct(corpus, id, .keep_all = TRUE)

tweets_all <- dplyr::bind_rows(tweets_opinion, tweets_presidente) |>
  dplyr::arrange(corpus, date, created_at, id)

## 3.3 Master de tweets y limpieza textual base ----

tweets_master <- tweets_all |>
  dplyr::mutate(
    doc_id = paste(corpus, id, sep = "_"),
    text_original = text,
    text_topic = text |>
      stringr::str_to_lower() |>
      stringr::str_replace_all("https?://\\S+", " ") |>
      repair_legacy_twitter_text() |>
      stringr::str_replace_all("@[A-Za-z0-9_]+", " ") |>
      stringr::str_replace_all("#", " ") |>
      stringr::str_replace_all("[^[:alnum:]áéíóúñü\\s]", " ") |>
      stringr::str_squish(),
    text_clean = text |>
      stringr::str_to_lower() |>
      stringr::str_replace_all("https?://\\S+", " ") |>
      repair_legacy_twitter_text() |>
      stringr::str_replace_all("@[A-Za-z0-9_]+", " ") |>
      stringr::str_replace_all("#", " ") |>
      stringr::str_replace_all("[^[:alpha:]áéíóúñü\\s]", " ") |>
      stringr::str_squish(),
    month = lubridate::floor_date(date, "month")
  )

# 4. Procesamiento de mercado raw ----

## 4.1 Lectura de series raw ----

date_frame <- tibble::tibble(date = seq(date_start, date_end, by = "day"))
market_daily <- date_frame

for (series_name in market_series) {
  market_daily <- dplyr::left_join(
    market_daily,
    read_market_raw_series(series_name),
    by = "date"
  )
}

## 4.2 Imputacion de fines de semana financieros ----

market_daily <- market_daily |>
  dplyr::arrange(date)

for (series_name in market_series) {
  market_daily[[paste0(series_name, "_observed")]] <- !is.na(market_daily[[series_name]])
}

market_carried <- market_daily |>
  tidyr::fill(dplyr::all_of(financial_series), .direction = "down")

weekend_dates <- lubridate::wday(market_daily$date, week_start = 1) >= 6

for (series_name in financial_series) {
  carried_col <- paste0(series_name, "_carried_forward")
  observed_col <- paste0(series_name, "_observed")
  market_daily[[carried_col]] <- weekend_dates & is.na(market_daily[[series_name]]) & !is.na(market_carried[[series_name]])
  market_daily[[series_name]] <- dplyr::if_else(
    market_daily[[carried_col]],
    market_carried[[series_name]],
    market_daily[[series_name]]
  )
  market_daily[[observed_col]] <- market_daily[[observed_col]] & !market_daily[[carried_col]]
}

market_master <- market_daily |>
  dplyr::mutate(
    energy_spot_price_carried_forward = FALSE,
    tes_slope_10y_1y = tes_10y - tes_1y,
    tes_slope_10y_1y_observed = tes_10y_observed & tes_1y_observed,
    tes_slope_10y_1y_carried_forward = tes_10y_carried_forward | tes_1y_carried_forward
  )

## 4.3 Fuentes y cobertura ----

market_sources <- tibble::tibble(
  series = c(financial_series, "tes_slope_10y_1y", "energy_spot_price"),
  provider = c(rep("Banco de la Republica", 6), "XM S.A. E.S.P."),
  source_url = c(
    trm_reference_url,
    colcap_reference_url,
    rep(tes_reference_url, 4),
    xm_daily_url
  ),
  retrieved_at = NA_character_,
  source_series_id = c(
    trm_series_id,
    colcap_series_id,
    tes_1y_series_id,
    tes_5y_series_id,
    tes_10y_series_id,
    NA_character_,
    energy_spot_price_metric_id
  ),
  source_series_name = c(
    "TRM",
    "COLCAP",
    "TES 1Y",
    "TES 5Y",
    "TES 10Y",
    "TES slope 10Y-1Y",
    energy_spot_price_series_name
  ),
  message = c(
    rep("Processed from data/raw/market/*_raw.csv.", 5),
    "Derived as TES 10Y minus TES 1Y.",
    paste(
      "Processed from data/raw/market/energy_spot_price_raw.csv.",
      "Units:", energy_spot_price_units,
      "No weekend carry-forward is applied."
    )
  )
)

market_coverage <- lapply(c(financial_series, "tes_slope_10y_1y", "energy_spot_price"), function(column) {
  values <- market_master[[column]]
  ok <- which(!is.na(values))
  coverage_ratio <- length(ok) / nrow(market_master)

  tibble::tibble(
    series = dplyr::recode(
      column,
      trm = "TRM",
      colcap = "COLCAP",
      tes_1y = "TES 1Y",
      tes_5y = "TES 5Y",
      tes_10y = "TES 10Y",
      tes_slope_10y_1y = "TES slope 10Y-1Y",
      energy_spot_price = "XM energy spot price"
    ),
    column = column,
    provider = market_sources$provider[match(column, market_sources$series)],
    source_url = market_sources$source_url[match(column, market_sources$series)],
    retrieved_at = NA_character_,
    rows = length(ok),
    non_missing_days = length(ok),
    expected_days = nrow(market_master),
    coverage_ratio = round(coverage_ratio, 3),
    first_date = first_non_missing_date(market_master$date, values),
    last_date = last_non_missing_date(market_master$date, values),
    status = dplyr::case_when(
      length(ok) == 0 ~ "missing",
      coverage_ratio < 0.60 ~ "partial",
      TRUE ~ "complete"
    )
  )
}) |>
  dplyr::bind_rows()

market_sources <- market_sources |>
  dplyr::left_join(
    market_coverage |>
      dplyr::transmute(series = column, rows, first_date, last_date, status),
    by = "series"
  ) |>
  dplyr::select(
    series, provider, source_url, retrieved_at, rows, first_date, last_date,
    status, source_series_id, source_series_name, message
  )

# 5. Validaciones finales ----

## 5.1 Columnas esperadas ----

tweet_cols <- c(
  "corpus", "corpus_label", "raw_source", "source_dir", "source_file",
  "id", "author_id", "created_at_raw", "created_at", "timestamp_utc",
  "timestamp_bogota", "date_bogota", "date", "text", "lang"
)
master_tweet_cols <- c(
  tweet_cols, "doc_id", "text_original", "text_topic", "text_clean", "month"
)
market_value_cols <- c(
  "date", "trm", "colcap", "tes_1y", "tes_5y", "tes_10y",
  "tes_slope_10y_1y", "energy_spot_price"
)
market_flag_cols <- c(
  paste0(c(financial_series, "energy_spot_price", "tes_slope_10y_1y"), "_observed"),
  paste0(c(financial_series, "energy_spot_price", "tes_slope_10y_1y"), "_carried_forward")
)
market_cols <- c(market_value_cols, market_flag_cols)

if (!identical(names(tweets_master), master_tweet_cols)) {
  stop("Las columnas de tweets_master no coinciden con el contrato esperado.", call. = FALSE)
}

market_master <- market_master |>
  dplyr::select(dplyr::all_of(market_cols))

if (!identical(names(market_master), market_cols)) {
  stop("Las columnas de market_master no coinciden con el contrato esperado.", call. = FALSE)
}

## 5.2 Objetos no vacios y llaves ----

if (nrow(tweets_master) == 0) {
  stop("tweets_master quedo vacio.", call. = FALSE)
}

if (nrow(market_master) == 0) {
  stop("market_master quedo vacio.", call. = FALSE)
}

if (any(is.na(tweets_master$id) | tweets_master$id == "") ||
    any(is.na(tweets_master$doc_id) | tweets_master$doc_id == "")) {
  stop("tweets_master contiene id o doc_id vacios.", call. = FALSE)
}

if (anyDuplicated(tweets_master[c("corpus", "id")]) > 0 || anyDuplicated(tweets_master$doc_id) > 0) {
  stop("tweets_master contiene claves duplicadas.", call. = FALSE)
}

if (!all(tweets_master$corpus %in% c("opinion", "presidente"))) {
  stop("tweets_master contiene valores de corpus no validos.", call. = FALSE)
}

if (any(is.na(tweets_master$date)) ||
    any(tweets_master$date < date_start | tweets_master$date > date_end)) {
  stop("tweets_master contiene fechas fuera del universo esperado.", call. = FALSE)
}

if (any(is.na(tweets_master$text_original)) || !is.character(tweets_master$text_clean)) {
  stop("tweets_master no conserva correctamente text_original/text_clean.", call. = FALSE)
}

if (anyDuplicated(market_master$date) > 0 || any(diff(market_master$date) < 0)) {
  stop("market_master debe contener fechas unicas y ordenadas.", call. = FALSE)
}

numeric_market_cols <- setdiff(market_cols, "date")
logical_market_cols <- market_flag_cols
numeric_market_cols <- setdiff(market_value_cols, "date")
if (!all(vapply(market_master[numeric_market_cols], is.numeric, logical(1)))) {
  stop("Las series de market_master deben ser numericas.", call. = FALSE)
}

if (!all(vapply(market_master[logical_market_cols], is.logical, logical(1)))) {
  stop("Las banderas de observacion/carry-forward de market_master deben ser logicas.", call. = FALSE)
}

if (any(vapply(market_master[numeric_market_cols], function(x) all(is.na(x)), logical(1)))) {
  stop("market_master contiene al menos una serie completamente vacia.", call. = FALSE)
}

# 6. Exportacion ----

## 6.1 Escritura de masters ----

tweets_master_path <- file.path(processed_dir, "tweets_master.csv")
market_master_path <- file.path(processed_dir, "market_master.csv")

write_csv_safe(tweets_master, tweets_master_path)
write_csv_safe(market_master, market_master_path)

## 6.2 Retiro de procesados obsoletos ----

obsolete_processed <- c(
  "tweets_all_normalized.csv", "tweets_normalized.csv", "tweets_opinion_normalized.csv",
  "tweets_presidente_archive_normalized.csv", "tweets_presidente_data_normalized.csv",
  "tweets_presidente_full_normalized.csv", "tweets_presidente_normalized.csv",
  "tweets_text_cleaned.csv", "market_daily.csv", "market_coverage.csv", "market_sources.csv"
)

obsolete_paths <- file.path(processed_dir, obsolete_processed)
unlink(obsolete_paths[file.exists(obsolete_paths)])

## 6.3 Resumen final ----

message("Filas tweets_master: ", nrow(tweets_master))
print(tweets_master |> dplyr::count(corpus, name = "filas"))
message("Rango tweets: ", min(tweets_master$date), " a ", max(tweets_master$date))
message("Filas market_master: ", nrow(market_master))
message("Rango mercado: ", min(market_master$date), " a ", max(market_master$date))
message("Output tweets: ", tweets_master_path)
message("Output mercado: ", market_master_path)
