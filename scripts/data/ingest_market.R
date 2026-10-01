#!/usr/bin/env Rscript

# ==============================================================================
# CONTRATO METODOLÓGICO Y PEDAGÓGICO: INGESTA DE DATOS DE MERCADO
# Archivo: scripts/data/ingest_market.R
# ------------------------------------------------------------------------------
# 1. PROPÓSITO GENERAL:
#    Descargar, unificar, validar y auditar de forma programática y reproducible
#    las series temporales diarias oficiales de los mercados financieros y
#    energéticos de Colombia a lo largo del periodo analítico fijado: 2022-08-01
#    a 2026-05-31 (1.400 días calendario continuos). Genera los archivos raw
#    en data/raw/market/ y las tablas de trazabilidad y cobertura en
#    output/tables/español/, sirviendo como insumo primario para market_master.csv.
#
# 2. FUENTES OFICIALES, URLS Y PROTOCOLOS DE ACCESO:
#    - TRM (Tasa Representativa del Mercado - COP/USD):
#      * Fuente primaria: Banco de la República - API SDMX REST.
#      * Flujo SDMX: ESTAT,DF_TRM_DAILY_HIST,1.0
#      * URL Base: https://totoro.banrep.gov.co/nsi-jax-ws/rest/data/ESTAT,DF_TRM_DAILY_HIST,1.0/all/ALL/
#      * Formato: XML SDMX GenericData 2.1 con dimensionAtObservation=TIME_PERIOD.
#      * Mecanismo de contingencia operacional (Fallback): Servicio Graficador REST Serie ID 1
#        https://suameca.banrep.gov.co/graficador-series/rest/graficadorService/consultaSerieParaGraficar?idSerie=1
#      * Referencia metodológica: https://www.banrep.gov.co/es/como-consultar-datos-historicos-tasa-representativa-mercado-trm-nuevo-portal-estadisticas
#      * Unidades: Pesos colombianos por dólar estadounidense (COP/USD).
#      * Frecuencia: Diaria continua (7 días a la semana, calculada por SFC).
#    - Índice Bursátil MSCI COLCAP:
#      * Fuente: Banco de la República / Bolsa de Valores de Colombia (BVC).
#      * URL: https://suameca.banrep.gov.co/graficador-series/rest/graficadorService/consultaSerieParaGraficar?idSerie=6
#      * Referencia metodológica: https://www.banrep.gov.co/en/node/50428
#      * Unidades: Puntos índice (base 1.000 puntos al 15 de enero de 2008).
#      * Frecuencia: Ruedas bursátiles hábiles (lunes a viernes, no festivos).
#    - Curva de Deuda Soberana (TES Cero Cupón en Pesos: 1Y, 5Y, 10Y):
#      * Fuente: Banco de la República (Curva cero cupón en pesos transaccional).
#      * URLs / IDs: Serie 15272 (tes_1y), Serie 15273 (tes_5y), Serie 15274 (tes_10y).
#      * Referencia metodológica: https://www.banrep.gov.co/en/node/50444
#      * Unidades: Tasa porcentual efectiva anual (% E.A.).
#      * Serie derivada: Pendiente de rendimientos tes_slope_10y_1y = tes_10y - tes_1y (% E.A.).
#    - Precio de Bolsa Nacional de Energía Eléctrica (Spot MEM):
#      * Fuente: XM S.A. E.S.P. (Operador y Administrador del MEM).
#      * API: SINERGOX Daily API POST JSON https://servapibi.xm.com.co/daily
#      * Métrica: PPPrecBolsNaci | Entidad: Sistema.
#      * Referencia metodológica: https://github.com/EquipoAnaliticaXM/API_XM
#      * Unidades: Pesos colombianos por kilovatio hora (COP/kWh).
#      * Frecuencia: Mercado físico continuo, 7 días a la semana (365 días al año).
#    - Variables Macroeconómicas Globales de Referencia (Yahoo Finance / FRED):
#      * Petróleo Crudo Brent (USD/bbl, FRED: DCOILBRENTEU / Yahoo: BZ=F) y
#        variables globales armonizadas downstream en el pipeline econométrico.
#        Este script captura los insumos soberanos institucionales de BanRep y XM.
#
# 3. INSUMOS REQUERIDOS:
#    - No requiere archivos locales preexistentes; consume endpoints REST en vivo.
#    - Identificador de cliente HTTP: User-Agent "colombian-president-tweets-research/1.0".
#    - Horizonte temporal: date_start (2022-08-01) a date_end (2026-05-31).
#
# 4. SALIDAS PRODUCIDAS:
#    - data/raw/market/trm_raw.csv (columnas: date, trm)
#    - data/raw/market/colcap_raw.csv (columnas: date, colcap)
#    - data/raw/market/tes_1y_raw.csv (columnas: date, tes_1y)
#    - data/raw/market/tes_5y_raw.csv (columnas: date, tes_5y)
#    - data/raw/market/tes_10y_raw.csv (columnas: date, tes_10y)
#    - data/raw/market/energy_spot_price_raw.csv (columnas: date, energy_spot_price)
#    - output/tables/español/ingesta_mercado_cobertura.csv (auditoría de cobertura)
#    - output/tables/español/ingesta_mercado_fuentes.csv (catálogo de trazabilidad)
#    - Base empírica directa para la consolidación de data/processed/market_master.csv.
#
# 5. REGLAS METODOLÓGICAS Y SUPUESTOS DE NEGOCIO:
#    - Salvaguarda No Destructiva: Si cualquier serie falla en su descarga (0 filas,
#      columna ausente o todo NA), la ejecución se detiene de inmediato con stop()
#      antes de escribir a disco, protegiendo los CSVs versionados contra caídas de red.
#    - Chunking de 31 Días para XM: La API de XM rechaza consultas con ventanas mayores
#      a 31 días calendario; se particiona el horizonte en bloques discretos secuenciales.
#    - Imputación de Fin de Semana (LOCF) en Mercados Bursátiles: Para COLCAP y TES
#      se aplica Last Observation Carried Forward (LOCF) exclusivamente en fines de
#      semana (wday >= 6), asumiendo continuidad en la valoración de cierre del viernes.
#    - Prohibición de Imputar Festivos Entre Semana: Días hábiles sin cotización
#      permanecen estrictamente como NA para no generar transacciones ficticias.
#    - Cobertura 100% Real para TRM y Energía: Operan continuamente 7 días a la semana
#      y no admiten arrastre ni imputación de fin de semana.
#    - Niveles Brutos vs Retornos: Se preservan niveles brutos para garantizar trazabilidad;
#      los retornos logarítmicos r_t = ln(P_t / P_{t-1}) o simples se calculan en los
#      modelos econométricos (VAR, GARCH, DCC) para evitar sesgos por transformaciones prematuras.
#    - Banderas de Linaje: Se generan explícitamente *_observed y *_carried_forward.
# ==============================================================================

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

# Resolución dinámica de la raíz del proyecto compatible con ejecución CLI
# (Rscript con parámetro --file=) y modo interactivo (getwd()). Valida la
# presencia de subcarpetas obligatorias para prevenir escrituras erróneas.
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

# Horizonte temporal de la investigación: 1.400 días calendario continuos
# (1 de agosto de 2022 al 31 de mayo de 2026), cubriendo la totalidad del
# periodo presidencial bajo estudio.
date_start <- as.Date("2022-08-01")
date_end <- as.Date("2026-05-31")
user_agent <- "colombian-president-tweets-research/1.0"

# Controles críticos de precondición en parámetros temporales
stopifnot(
  "date_start debe ser un objeto Date valido no nulo" = inherits(date_start, "Date") && !is.na(date_start),
  "date_end debe ser un objeto Date valido no nulo" = inherits(date_end, "Date") && !is.na(date_end),
  "date_start debe ser estrictamente anterior a date_end" = date_start < date_end
)

## 1.4 Constantes de fuentes y unidades de medida ----

# Endpoints oficiales del Banco de la República
banrep_sdmx_base_url <- "https://totoro.banrep.gov.co/nsi-jax-ws/rest/data"
banrep_graficador_base_url <- "https://suameca.banrep.gov.co/graficador-series/rest/graficadorService/consultaSerieParaGraficar"

# TRM: Tasa Representativa del Mercado
# Unidades: Pesos colombianos por dólar estadounidense (COP/USD).
# Frecuencia: Diaria continua (1.400 observaciones, certificada por SFC).
trm_sdmx_flow <- "ESTAT,DF_TRM_DAILY_HIST,1.0"
trm_series_id <- 1
trm_reference_url <- "https://www.banrep.gov.co/es/como-consultar-datos-historicos-tasa-representativa-mercado-trm-nuevo-portal-estadisticas"

# MSCI COLCAP: Índice bursátil accionario de la BVC
# Unidades: Puntos índice (base 1.000 puntos al 15 de enero de 2008).
# Frecuencia: Días hábiles bursátiles (lunes a viernes no festivos).
colcap_series_id <- 6
colcap_reference_url <- "https://www.banrep.gov.co/en/node/50428"

# Curva Cero Cupón en Pesos de Títulos de Deuda Pública Soberana (TES)
# Unidades: Tasa porcentual efectiva anual (% E.A.).
# Frecuencia: Días hábiles bursátiles (lunes a viernes no festivos).
# Serie derivada: tes_slope_10y_1y = tes_10y - tes_1y (spread en puntos porcentuales % E.A.).
tes_series_ids <- c(
  tes_1y = 15272,
  tes_5y = 15273,
  tes_10y = 15274
)
tes_reference_url <- "https://www.banrep.gov.co/en/node/50444"

# Precio de Bolsa Nacional de Energía Eléctrica (Spot MEM) - XM S.A. E.S.P.
# Unidades: Pesos colombianos por kilovatio hora (COP/kWh).
# Frecuencia: Mercado físico continuo 7 días a la semana (365 días al año).
# Restricción de API: Ventana máxima de 31 días calendario por consulta POST.
xm_api_base_url <- "https://servapibi.xm.com.co"
xm_daily_endpoint <- "/daily"
energy_spot_price_metric_id <- "PPPrecBolsNaci"
energy_spot_price_entity <- "Sistema"
energy_spot_price_series_name <- "Precio Bolsa Nacional Ponderado por Sistema"
energy_spot_price_units <- "COP/kWh"
energy_spot_price_max_days <- 31
energy_spot_price_reference_url <- "https://github.com/EquipoAnaliticaXM/API_XM"

# Catálogo de series a procesar
market_series <- c("trm", "colcap", "tes_1y", "tes_5y", "tes_10y", "energy_spot_price")
financial_series <- c("trm", "colcap", "tes_1y", "tes_5y", "tes_10y")

## 1.5 Funciones auxiliares necesarias ----

# Operador coalescente nulo: retorna y si x es nulo o de longitud 0
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

# Escritura atómica y segura en CSV: garantiza la creación recursiva de directorios
write_csv_safe <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
  invisible(path)
}

# Primera fecha no faltante en un vector cronológico
first_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[min(ok)]
}

# Última fecha no faltante en un vector cronológico
last_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[max(ok)]
}

# Estructura de fila de auditoría para registro de fuentes y metadatos
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

# Generador de estructura vacía tipada en caso de fallo no recuperable de descarga
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

# Partición temporal en bloques discretos (Chunking):
# Justificación metodológica: El API SINERGOX de XM impone un límite estricto
# de 31 días por petición POST. Esta función fragmenta el rango completo
# [start_date, end_date] en bloques secuenciales de tamaño máximo max_days.
make_date_windows <- function(start_date, end_date, max_days = 31) {
  stopifnot(
    "start_date debe ser menor o igual a end_date" = as.Date(start_date) <= as.Date(end_date),
    "max_days debe ser un entero positivo mayor o igual a 1" = is.numeric(max_days) && max_days >= 1
  )

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

# Descarga la Tasa Representativa del Mercado (COP/USD) mediante el API SDMX REST.
# Utiliza consultas XPath con local-name() para sortear variaciones en los namespaces
# XML del estándar SDMX GenericData 2.1. Si el endpoint SDMX presenta fallos de red,
# latencia o cambios de esquema, un bloque tryCatch redirige automáticamente la
# consulta al servicio Graficador del Banco de la República (fallback operacional).
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

# Consulta genérica de series históricas al servicio Graficador del BanRep.
# El API retorna un array JSON de pares [timestamp_milisegundos, valor].
# Se divide entre 1.000 para convertir de epoch en milisegundos a segundos POSIXct,
# parseando a Date en UTC. Se aplica deduplicación diaria conservando el último valor.
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

# Ingesta del índice bursátil accionario MSCI COLCAP (Serie 6)
fetch_banrep_colcap <- function() {
  fetch_banrep_graficador_series(
    series_id = colcap_series_id,
    value_col = "colcap",
    label = "COLCAP",
    reference_url = colcap_reference_url
  )
}

# Ingesta de tasas de la curva cero cupón en pesos de Deuda Pública Soberana (TES)
# Plazos analizados: 1 año (15272), 5 años (15273) y 10 años (15274) en % E.A.
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

# Ingesta del Precio de Bolsa Nacional Ponderado por Sistema (PPPrecBolsNaci)
# desde la API SINERGOX Daily de XM S.A. E.S.P. en unidades COP/kWh.
# Emplea make_date_windows() para respetar el límite de 31 días por consulta.
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
    stopifnot(
      "Las ventanas de XM deben cubrir exactamente el rango [date_start, date_end]" =
        nrow(windows) > 0L && min(windows$date_start) == date_start && max(windows$date_end) == date_end
    )
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

# Consulta coordinada de todas las series del panel analítico
series_results <- list(
  trm = fetch_banrep_trm_sdmx(),
  colcap = fetch_banrep_colcap(),
  tes_1y = fetch_banrep_tes("tes_1y"),
  tes_5y = fetch_banrep_tes("tes_5y"),
  tes_10y = fetch_banrep_tes("tes_10y"),
  energy_spot_price = fetch_xm_energy_spot_price()
)

# Salvaguarda No Destructiva:
# Si cualquier serie no pudo ser descargada, contiene 0 filas o su vector
# de observaciones es completamente NA, se aborta la ejecución con stop()
# ANTES de modificar o sobrescribir los archivos raw versionados en el disco.
missing_series <- names(series_results)[vapply(names(series_results), function(series_name) {
  result <- series_results[[series_name]]
  nrow(result$data) == 0L ||
    !series_name %in% names(result$data) ||
    all(is.na(result$data[[series_name]]))
}, logical(1))]

if (length(missing_series) > 0L) {
  stop(
    "No se actualizaron los archivos raw: faltan observaciones para ",
    paste(missing_series, collapse = ", "),
    ". Revise las fuentes y reintente la ingesta.",
    call. = FALSE
  )
}

# Grilla cronológica diaria completa (1.400 fechas calendario continuas)
date_frame <- tibble::tibble(date = seq(date_start, date_end, by = "day"))

# Unión secuencial (left join) de todas las series sobre la grilla continua
market_daily <- purrr::reduce(
  purrr::map(series_results, "data"),
  dplyr::left_join,
  by = "date",
  .init = date_frame
) |>
  dplyr::arrange(date)

## 3.2 Imputacion de fines de semana financieros y derivacion de series ----

# 1. Banderas iniciales de observación real: TRUE si el dato existe directamente en la fuente
for (series_name in market_series) {
  market_daily[[paste0(series_name, "_observed")]] <- !is.na(market_daily[[series_name]])
}

# 2. Arrastre de último valor observado (LOCF) para series financieras bursátiles
market_carried <- market_daily |>
  tidyr::fill(dplyr::all_of(financial_series), .direction = "down")

weekend_dates <- lubridate::wday(market_daily$date, week_start = 1) >= 6

# Regla econométrica: El carry-forward se aplica EXCLUSIVAMENTE en fines de semana
# (sábados y domingos, wday >= 6) donde los mercados bursátiles están cerrados.
# Los festivos bursátiles entre semana NO se imputan (permanecen NA) para no inventar
# liquidez ni distorsionar volatilidades en días hábiles.
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

# 3. Derivaciones y series energéticas:
# - El precio spot de energía opera 7 días continuos en el mercado físico; no admite carry-forward.
# - La pendiente de la curva sovereign (tes_slope_10y_1y) es el spread entre 10Y y 1Y (% E.A.).
market_daily <- market_daily |>
  dplyr::mutate(
    energy_spot_price_carried_forward = FALSE,
    tes_slope_10y_1y = tes_10y - tes_1y,
    tes_slope_10y_1y_observed = tes_10y_observed & tes_1y_observed,
    tes_slope_10y_1y_carried_forward = tes_10y_carried_forward | tes_1y_carried_forward
  )

## 3.3 Fuentes y tablas de cobertura para auditoria ----

# Consolidación del catálogo de trazabilidad de proveedores y endpoints
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

# Cálculo de ratios de cobertura temporal y auditoría de integridad por serie
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

# 4. Validaciones finales de esquema e integridad ----

## 4.1 Controles stopifnot() de market_daily ----

expected_market_cols <- c(
  "date", "trm", "colcap", "tes_1y", "tes_5y", "tes_10y",
  "energy_spot_price", "tes_slope_10y_1y",
  paste0(c(financial_series, "energy_spot_price", "tes_slope_10y_1y"), "_observed"),
  paste0(c(financial_series, "energy_spot_price", "tes_slope_10y_1y"), "_carried_forward")
)
missing_market_cols <- setdiff(expected_market_cols, names(market_daily))
expected_days_count <- as.integer(date_end - date_start + 1L)

stopifnot(
  "Todas las columnas requeridas deben estar presentes en market_daily" =
    length(missing_market_cols) == 0L,
  "market_daily no puede estar vacio (nrow == 0)" =
    nrow(market_daily) > 0L,
  "market_daily debe contener exactamente 1.400 fechas calendario continuas" =
    nrow(market_daily) == expected_days_count,
  "Las fechas de market_daily no deben contener duplicados" =
    !anyDuplicated(market_daily$date),
  "Las fechas de market_daily deben ser estrictamente consecutivas diarias" =
    all(diff(market_daily$date) == 1L),
  "Las series de mercado en market_daily deben ser de tipo numerico" =
    all(vapply(market_daily[c(market_series, "tes_slope_10y_1y")], is.numeric, logical(1))),
  "Las banderas de observacion y arrastre en market_daily deben ser de tipo logico" =
    all(vapply(market_daily[grep("_(observed|carried_forward)$", names(market_daily), value = TRUE)], is.logical, logical(1)))
)

## 4.2 Controles stopifnot() de tablas de auditoria ----

stopifnot(
  "market_coverage debe auditar exactamente las 7 series del panel" =
    nrow(market_coverage) == nrow(series_map),
  "El ratio de cobertura en market_coverage debe pertenecer al intervalo cerrado [0, 1]" =
    all(market_coverage$coverage_ratio >= 0 & market_coverage$coverage_ratio <= 1),
  "market_sources debe contener registros no nulos para todas las series consultadas" =
    nrow(market_sources) >= length(market_series)
)

# 5. Exportacion ----

## 5.1 Escritura de archivos raw individuales ----

dir.create(raw_market_dir, recursive = TRUE, showWarnings = FALSE)

for (series_name in names(series_results)) {
  write_csv_safe(
    series_results[[series_name]]$data,
    file.path(raw_market_dir, paste0(series_name, "_raw.csv"))
  )
}

## 5.2 Escritura de tablas de auditoria ----

write_csv_safe(market_coverage, file.path(audit_dir, "ingesta_mercado_cobertura.csv"))
write_csv_safe(market_sources, file.path(audit_dir, "ingesta_mercado_fuentes.csv"))

## 5.3 Mensaje final ----

message("Datos de mercado actualizados en data/raw/market/; auditorias guardadas en output/tables/español/.")
