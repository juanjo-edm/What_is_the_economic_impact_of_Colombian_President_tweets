#!/usr/bin/env Rscript

# 1. Setup ----

## 1.1 Librerias ----

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(purrr)
library(httr2)
library(xml2)
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
raw_market_dir <- file.path(repo_dir, "data", "raw", "market")
audit_dir <- file.path(repo_dir, "output", "tables", "español")

## 1.3 Parametros del script ----

date_start <- as.Date("2022-08-01")
date_end <- as.Date("2026-05-31")
user_agent <- "colombian-president-tweets-research/1.0"

## 1.4 Constantes de fuentes ----

banrep_sdmx_base_url <- "https://totoro.banrep.gov.co/nsi-jax-ws/rest/data"
banrep_graficador_base_url <- "https://suameca.banrep.gov.co/graficador-series/rest/graficadorService/consultaSerieParaGraficar"

trm_sdmx_flow <- "ESTAT,DF_TRM_DAILY_HIST,1.0"
trm_series_id <- 1
trm_reference_url <- "https://www.banrep.gov.co/es/como-consultar-datos-historicos-tasa-representativa-mercado-trm-nuevo-portal-estadisticas"

colcap_series_id <- 6
colcap_reference_url <- "https://www.banrep.gov.co/en/node/50428"

tes_series_ids <- c(
  tes_1y = 15272,
  tes_5y = 15273,
  tes_10y = 15274
)
tes_reference_url <- "https://www.banrep.gov.co/en/node/50444"

xm_api_base_url <- "https://servapibi.xm.com.co"
xm_daily_endpoint <- "/daily"
energy_spot_price_metric_id <- "PPPrecBolsNaci"
energy_spot_price_entity <- "Sistema"
energy_spot_price_series_name <- "Precio Bolsa Nacional Ponderado por Sistema"
energy_spot_price_units <- "COP/kWh"
energy_spot_price_max_days <- 31
energy_spot_price_reference_url <- "https://github.com/EquipoAnaliticaXM/API_XM"

market_series <- c("trm", "colcap", "tes_1y", "tes_5y", "tes_10y", "energy_spot_price")
financial_series <- c("trm", "colcap", "tes_1y", "tes_5y", "tes_10y")

## 1.5 Funciones auxiliares necesarias ----

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

write_csv_safe <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
  invisible(path)
}

first_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[min(ok)]
}

last_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[max(ok)]
}

market_source_row <- function(series, provider, source_url, retrieved_at = NA_character_,
                              rows = 0L, first_date = as.Date(NA), last_date = as.Date(NA),
                              status = "retrieved", source_series_id = NA_character_,
                              source_series_name = NA_character_, message = NA_character_) {
  tibble::tibble(
    series = series,
    provider = provider,
    source_url = source_url,
    retrieved_at = retrieved_at,
    rows = as.integer(rows),
    first_date = as.Date(first_date),
    last_date = as.Date(last_date),
    status = status,
    source_series_id = source_series_id,
    source_series_name = source_series_name,
    message = message
  )
}

empty_market_result <- function(series, provider, source_url, retrieved_at = NA_character_, status = "missing") {
  data <- tibble::tibble(date = as.Date(character()))
  data[[series]] <- numeric()

  list(
    data = data,
    source = market_source_row(
      series = series,
      provider = provider,
      source_url = source_url,
      retrieved_at = retrieved_at,
      rows = 0L,
      status = status
    )
  )
}

make_date_windows <- function(start_date, end_date, max_days = 31) {
  current_start <- as.Date(start_date)
  final_date <- as.Date(end_date)
  windows <- list()
  i <- 1L

  while (current_start <= final_date) {
    current_end <- min(current_start + lubridate::days(max_days - 1), final_date)
    windows[[i]] <- tibble::tibble(
      date_start = current_start,
      date_end = current_end
    )
    current_start <- current_end + lubridate::days(1)
    i <- i + 1L
  }

  dplyr::bind_rows(windows)
}

# 2. Descarga de insumos ----

## 2.1 TRM desde BanRep SDMX ----

fetch_banrep_trm_sdmx <- function() {
  source_url <- paste0(banrep_sdmx_base_url, "/", trm_sdmx_flow, "/all/ALL/")
  retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  empty <- empty_market_result(
    series = "trm",
    provider = "Banco de la Republica",
    source_url = source_url,
    retrieved_at = retrieved_at,
    status = "failed"
  )

  tryCatch({
    response <- httr2::request(source_url) |>
      httr2::req_url_query(
        startPeriod = as.character(date_start),
        endPeriod = as.character(date_end),
        dimensionAtObservation = "TIME_PERIOD",
        detail = "full"
      ) |>
      httr2::req_headers(Accept = "application/vnd.sdmx.genericdata+xml;version=2.1") |>
      httr2::req_user_agent(user_agent) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_perform()

    doc <- httr2::resp_body_string(response) |>
      xml2::read_xml()

    obs <- xml2::xml_find_all(doc, ".//*[local-name()='Obs']")
    dates <- xml2::xml_attr(
      xml2::xml_find_first(obs, ".//*[local-name()='ObsDimension']"),
      "value"
    )
    values <- xml2::xml_attr(
      xml2::xml_find_first(obs, ".//*[local-name()='ObsValue']"),
      "value"
    )

    data <- tibble::tibble(
      date = as.Date(dates),
      trm = suppressWarnings(as.numeric(values))
    ) |>
      dplyr::filter(date >= date_start, date <= date_end, !is.na(date)) |>
      dplyr::arrange(date) |>
      dplyr::group_by(date) |>
      dplyr::summarise(trm = dplyr::last(trm[!is.na(trm)], default = NA_real_), .groups = "drop")

    list(
      data = data,
      source = market_source_row(
        series = "trm",
        provider = "Banco de la Republica",
        source_url = source_url,
        retrieved_at = retrieved_at,
        rows = nrow(data),
        first_date = first_non_missing_date(data$date, data$trm),
        last_date = last_non_missing_date(data$date, data$trm),
        status = if (nrow(data) == 0) "missing" else "retrieved"
      )
    )
  }, error = function(e) {
    fallback <- fetch_banrep_graficador_series(
      series_id = trm_series_id,
      value_col = "trm",
      label = "TRM",
      reference_url = trm_reference_url
    )
    fallback$source$status <- if (fallback$source$status == "retrieved") {
      "retrieved via graficador fallback"
    } else {
      fallback$source$status
    }
    fallback$source$message <- paste(
      "Operational BanRep graficador fallback after SDMX request failed:",
      conditionMessage(e)
    )
    fallback
  })
}

## 2.2 Series BanRep desde graficador ----

fetch_banrep_graficador_series <- function(series_id, value_col, label, reference_url) {
  source_url <- banrep_graficador_base_url
  retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  empty <- empty_market_result(
    series = value_col,
    provider = "Banco de la Republica",
    source_url = paste0(source_url, "?idSerie=", series_id),
    retrieved_at = retrieved_at,
    status = "failed"
  )

  tryCatch({
    response <- httr2::request(source_url) |>
      httr2::req_url_query(idSerie = series_id) |>
      httr2::req_user_agent(user_agent) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_perform()

    payload <- httr2::resp_body_json(response, simplifyVector = FALSE)
    if (length(payload) == 0 || is.null(payload[[1]]$data)) {
      stop("BanRep response did not include a data array for series ", series_id)
    }

    meta <- payload[[1]]
    data <- purrr::map_dfr(meta$data, function(point) {
      tibble::tibble(
        date = as.Date(as.POSIXct(as.numeric(point[[1]]) / 1000, origin = "1970-01-01", tz = "UTC")),
        value = suppressWarnings(as.numeric(point[[2]]))
      )
    }) |>
      dplyr::filter(date >= date_start, date <= date_end, !is.na(date)) |>
      dplyr::arrange(date) |>
      dplyr::group_by(date) |>
      dplyr::summarise(value = dplyr::last(value[!is.na(value)], default = NA_real_), .groups = "drop") |>
      dplyr::rename(!!value_col := value)

    provider <- paste(
      "Banco de la Republica",
      meta$fuenteCorta %||% meta$fuente %||% "",
      sep = " / "
    ) |>
      stringr::str_squish()

    list(
      data = data,
      source = market_source_row(
        series = value_col,
        provider = provider,
        source_url = reference_url %||% paste0(source_url, "?idSerie=", series_id),
        retrieved_at = retrieved_at,
        rows = nrow(data),
        first_date = first_non_missing_date(data$date, data[[value_col]]),
        last_date = last_non_missing_date(data$date, data[[value_col]]),
        status = if (nrow(data) == 0) "missing" else "retrieved",
        source_series_id = as.character(series_id),
        source_series_name = meta$nombre %||% label
      )
    )
  }, error = function(e) {
    warning("Could not retrieve ", label, " from BanRep graficador: ", conditionMessage(e))
    empty$source$message <- conditionMessage(e)
    empty
  })
}

fetch_banrep_colcap <- function() {
  fetch_banrep_graficador_series(
    series_id = colcap_series_id,
    value_col = "colcap",
    label = "COLCAP",
    reference_url = colcap_reference_url
  )
}

fetch_banrep_tes <- function(value_col) {
  labels <- c(
    tes_1y = "TES cero cupon pesos 1 ano",
    tes_5y = "TES cero cupon pesos 5 anos",
    tes_10y = "TES cero cupon pesos 10 anos"
  )

  fetch_banrep_graficador_series(
    series_id = tes_series_ids[[value_col]],
    value_col = value_col,
    label = labels[[value_col]],
    reference_url = tes_reference_url
  )
}

## 2.3 Precio diario de energia XM ----

fetch_xm_energy_spot_price <- function() {
  source_url <- paste0(xm_api_base_url, xm_daily_endpoint)
  retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  empty <- empty_market_result(
    series = "energy_spot_price",
    provider = "XM S.A. E.S.P.",
    source_url = source_url,
    retrieved_at = retrieved_at,
    status = "failed"
  )

  tryCatch({
    windows <- make_date_windows(date_start, date_end, max_days = energy_spot_price_max_days)
    data <- purrr::pmap_dfr(windows, function(date_start, date_end) {
      response <- httr2::request(source_url) |>
        httr2::req_headers("Content-Type" = "application/json") |>
        httr2::req_body_json(
          list(
            MetricId = energy_spot_price_metric_id,
            StartDate = as.character(date_start),
            EndDate = as.character(date_end),
            Entity = energy_spot_price_entity
          ),
          auto_unbox = TRUE
        ) |>
        httr2::req_user_agent(user_agent) |>
        httr2::req_retry(max_tries = 3) |>
        httr2::req_perform()

      payload <- httr2::resp_body_json(response, simplifyVector = FALSE)
      purrr::map_dfr(payload$Items %||% list(), function(item) {
        entities <- item$DailyEntities %||% list()
        purrr::map_dfr(entities, function(entity_row) {
          tibble::tibble(
            date = as.Date(substr(item$Date %||% NA_character_, 1, 10)),
            entity = as.character(entity_row$Id %||% energy_spot_price_entity),
            energy_spot_price = suppressWarnings(as.numeric(entity_row$Value %||% NA_real_))
          )
        })
      })
    }) |>
      dplyr::filter(
        !is.na(date),
        date >= date_start,
        date <= date_end,
        .data$entity == energy_spot_price_entity
      ) |>
      dplyr::arrange(date) |>
      dplyr::group_by(date) |>
      dplyr::summarise(
        energy_spot_price = dplyr::last(energy_spot_price[!is.na(energy_spot_price)], default = NA_real_),
        .groups = "drop"
      )

    list(
      data = data,
      source = market_source_row(
        series = "energy_spot_price",
        provider = "XM S.A. E.S.P.",
        source_url = source_url,
        retrieved_at = retrieved_at,
        rows = sum(!is.na(data$energy_spot_price)),
        first_date = first_non_missing_date(data$date, data$energy_spot_price),
        last_date = last_non_missing_date(data$date, data$energy_spot_price),
        status = if (all(is.na(data$energy_spot_price))) "missing" else "retrieved",
        source_series_id = energy_spot_price_metric_id,
        source_series_name = energy_spot_price_series_name,
        message = paste(
          "XM SINERGOX daily API.",
          "Entity:", energy_spot_price_entity,
          "Units:", energy_spot_price_units,
          "Reference:", energy_spot_price_reference_url
        )
      )
    )
  }, error = function(e) {
    warning("Could not retrieve XM energy spot price: ", conditionMessage(e))
    empty$source$message <- conditionMessage(e)
    empty
  })
}

# 3. Procesamiento de mercado ----

## 3.1 Union de series diarias ----

series_results <- list(
  trm = fetch_banrep_trm_sdmx(),
  colcap = fetch_banrep_colcap(),
  tes_1y = fetch_banrep_tes("tes_1y"),
  tes_5y = fetch_banrep_tes("tes_5y"),
  tes_10y = fetch_banrep_tes("tes_10y"),
  energy_spot_price = fetch_xm_energy_spot_price()
)

date_frame <- tibble::tibble(date = seq(date_start, date_end, by = "day"))

market_daily <- purrr::reduce(
  purrr::map(series_results, "data"),
  dplyr::left_join,
  by = "date",
  .init = date_frame
) |>
  dplyr::arrange(date)

## 3.2 Imputacion de fines de semana financieros ----

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

market_daily <- market_daily |>
  dplyr::mutate(
    energy_spot_price_carried_forward = FALSE,
    tes_slope_10y_1y = tes_10y - tes_1y,
    tes_slope_10y_1y_observed = tes_10y_observed & tes_1y_observed,
    tes_slope_10y_1y_carried_forward = tes_10y_carried_forward | tes_1y_carried_forward
  )

## 3.3 Fuentes y cobertura ----

market_sources <- dplyr::bind_rows(c(
  purrr::map(series_results, "source"),
  list(market_source_row(
    series = "tes_slope_10y_1y",
    provider = "Banco de la Republica",
    source_url = tes_reference_url,
    retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    rows = sum(!is.na(market_daily$tes_slope_10y_1y)),
    first_date = first_non_missing_date(market_daily$date, market_daily$tes_slope_10y_1y),
    last_date = last_non_missing_date(market_daily$date, market_daily$tes_slope_10y_1y),
    status = if (all(is.na(market_daily$tes_slope_10y_1y))) "missing" else "derived",
    message = "Derived as TES 10Y zero-coupon rate minus TES 1Y zero-coupon rate."
  ))
))

series_map <- tibble::tribble(
  ~series, ~column,
  "TRM", "trm",
  "COLCAP", "colcap",
  "TES 1Y", "tes_1y",
  "TES 5Y", "tes_5y",
  "TES 10Y", "tes_10y",
  "TES slope 10Y-1Y", "tes_slope_10y_1y",
  "XM energy spot price", "energy_spot_price"
)

market_coverage <- purrr::pmap_dfr(series_map, function(series, column) {
  values <- market_daily[[column]]
  source <- market_sources |>
    dplyr::filter(.data$series == column) |>
    dplyr::slice_head(n = 1)

  non_missing <- sum(!is.na(values))
  coverage_ratio <- if (nrow(market_daily) == 0) 0 else round(non_missing / nrow(market_daily), 3)

  tibble::tibble(
    series = series,
    column = column,
    provider = if (nrow(source) == 0) NA_character_ else source$provider[[1]],
    source_url = if (nrow(source) == 0) NA_character_ else source$source_url[[1]],
    retrieved_at = if (nrow(source) == 0) NA_character_ else source$retrieved_at[[1]],
    rows = if (nrow(source) == 0) 0L else source$rows[[1]],
    non_missing_days = non_missing,
    expected_days = nrow(market_daily),
    coverage_ratio = coverage_ratio,
    first_date = first_non_missing_date(market_daily$date, values),
    last_date = last_non_missing_date(market_daily$date, values),
    status = dplyr::case_when(
      non_missing == 0 ~ "missing",
      coverage_ratio < 0.60 ~ "partial",
      TRUE ~ "complete"
    )
  )
})

# 4. Validaciones finales ----

## 4.1 Columnas esperadas ----

expected_market_cols <- c(
  "date", "trm", "colcap", "tes_1y", "tes_5y", "tes_10y",
  "energy_spot_price", "tes_slope_10y_1y",
  paste0(c(financial_series, "energy_spot_price", "tes_slope_10y_1y"), "_observed"),
  paste0(c(financial_series, "energy_spot_price", "tes_slope_10y_1y"), "_carried_forward")
)
missing_market_cols <- setdiff(expected_market_cols, names(market_daily))

if (length(missing_market_cols) > 0) {
  stop("Faltan columnas esperadas en market_daily: ", paste(missing_market_cols, collapse = ", "), call. = FALSE)
}

if (nrow(market_daily) == 0) {
  stop("market_daily quedo vacio.", call. = FALSE)
}

## 4.2 Duplicados de fecha ----

duplicated_dates <- market_daily$date[duplicated(market_daily$date)]
if (length(duplicated_dates) > 0) {
  stop("market_daily tiene fechas duplicadas.", call. = FALSE)
}

# 5. Exportacion ----

## 5.1 Escritura de raw market ----

dir.create(raw_market_dir, recursive = TRUE, showWarnings = FALSE)

for (series_name in names(series_results)) {
  write_csv_safe(
    series_results[[series_name]]$data,
    file.path(raw_market_dir, paste0(series_name, "_raw.csv"))
  )
}

## 5.2 Escritura de auditorias de descarga ----

write_csv_safe(market_coverage, file.path(audit_dir, "ingesta_mercado_cobertura.csv"))
write_csv_safe(market_sources, file.path(audit_dir, "ingesta_mercado_fuentes.csv"))

## 5.3 Mensaje final ----

message("Datos de mercado actualizados en data/raw/market/; auditorias guardadas en output/tables/español/.")
