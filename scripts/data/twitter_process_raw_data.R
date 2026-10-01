#!/usr/bin/env Rscript

# ==============================================================================
# CONTRATO METODOLÓGICO Y PEDAGÓGICO: PROCESAMIENTO Y NORMALIZACIÓN DE DATOS
# Archivo: scripts/data/twitter_process_raw_data.R
# ------------------------------------------------------------------------------
# 1. PROPÓSITO GENERAL:
#    Armonizar, limpiar, calibrar temporalmente y consolidar los dos conjuntos de
#    datos maestros del proyecto de investigación:
#    a) data/processed/tweets_master.csv: 28.307 tweets clasificados en los
#       corpus de opinión ciudadana (13.648) y presidencial (14.659), con tipado
#       seguro de identificadores de 64 bits, doble capa de texto (tópicos y
#       sentimiento) y calibración horaria oficial de Colombia (UTC -> America/Bogota).
#    b) data/processed/market_master.csv: Panel diario continuo de 1.400 fechas
#       (2022-08-01 a 2026-05-31) para 7 series de mercado financiero y energético,
#       con imputación de fin de semana (LOCF) y banderas booleanas de linaje.
#    Adicionalmente, purgar los archivos procesados obsoletos o intermedios para
#    garantizar la higiene y reproducibilidad estricta de data/processed/.
#
# 2. FUENTES E INSUMOS REQUERIDOS:
#    - Corpus de Opinión Pública Ciudadana:
#      data/raw/twitter/Opinión sobre Petro/*.csv (46 archivos mensuales continuos
#      desde agosto de 2022 hasta mayo de 2026, Twitter API v2 / Academic Archive).
#    - Corpus Presidencial (@petrogustavo):
#      data/raw/twitter/Tweets de Gustavo Petro/petrogustavo_full.csv
#      (respaldos de contingencia en twitter_data/ y twitter_archive/).
#    - Insumos de Mercado Brutos:
#      data/raw/market/{trm,colcap,tes_1y,tes_5y,tes_10y,energy_spot_price}_raw.csv
#      descargados previamente por scripts/data/ingest_market.R.
#
# 3. SALIDAS PRODUCIDAS (CONTRATOS MAESTROS):
#    - data/processed/tweets_master.csv (20 columnas exactas, 28.307 filas):
#      corpus, corpus_label, raw_source, source_dir, source_file, id, author_id,
#      created_at_raw, created_at, timestamp_utc, timestamp_bogota, date_bogota,
#      date, text, lang, doc_id, text_original, text_topic, text_clean, month.
#    - data/processed/market_master.csv (22 columnas exactas, 1.400 filas):
#      date, trm, colcap, tes_1y, tes_5y, tes_10y, tes_slope_10y_1y, energy_spot_price,
#      trm_observed, colcap_observed, tes_1y_observed, tes_5y_observed, tes_10y_observed,
#      energy_spot_price_observed, tes_slope_10y_1y_observed,
#      trm_carried_forward, colcap_carried_forward, tes_1y_carried_forward,
#      tes_5y_carried_forward, tes_10y_carried_forward,
#      energy_spot_price_carried_forward, tes_slope_10y_1y_carried_forward.
#
# 4. REGLAS METODOLÓGICAS Y SUPUESTOS DE NEGOCIO:
#    - Tipado Seguro de IDs de 64 Bits (Snowflake IDs): Los identificadores numéricos
#      de Twitter (~1.8e18) superan el límite de representación entera exacta de
#      coma flotante IEEE 754 de doble precisión (~9e15). Para evitar el truncamiento
#      de los últimos 3 dígitos y falsas colisiones por redondeo, se exige la lectura
#      y almacenamiento estricto como cadenas de texto (col_character()).
#    - Calibración Horaria Local (America/Bogota, UTC-5): Los tweets se registran
#      originalmente con timestamp UTC. Sin embargo, el mercado financiero y los
#      despachos del gobierno operan en la hora legal de Colombia. Evaluar la fecha
#      en UTC indexaría erróneamente en el día siguiente de mercado los tweets emitidos
#      entre las 19:00 y las 23:59 hora local de Bogotá (~2.935 tweets afectados).
#      Se exige conversión formal con with_tz(parsed_time, "America/Bogota") y
#      as.Date(parsed_time_bogota, tz = "America/Bogota") para evitar look-ahead bias.
#    - Umbral Presidencial (2022-08-07): La investidura presidencial de Gustavo Petro
#      ocurrió el 7 de agosto de 2022. Los tweets anteriores corresponden a su periodo
#      como presidente electo y se filtran rigurosamente (fecha >= '2022-08-07'). El
#      corpus de opinión ciudadana, por su parte, abarca desde el 1 de agosto de 2022
#      para medir la conversación pública base previa a la posesión.
#    - Pipeline Textual en Dos Capas Metodológicas:
#      * text_topic: Normalización a minúsculas, remoción de URLs, reparación de
#        secuencias de acentos legados, eliminación de menciones (@), almohadillas (#)
#        y signos, CONSERVANDO números ([:alnum:]). Vital para modelos de tópicos
#        (STM, KeyATM) donde números de leyes, reformas o montos son informativos.
#      * text_clean: Normalización alfabética pura ([:alpha:]), retirando dígitos.
#        Vital para modelos léxicos de sentimiento (NRC, Sentometrics, Wordfish)
#        donde números aislados sesgan el cómputo de polaridad.
#    - Deduplicación Determinista: Ordenamiento por (date, created_at, id) y retención
#      de la primera ocurrencia por (corpus, id). Creación de clave primaria global
#      doc_id = paste(corpus, id, sep = "_").
#    - Imputación Financiera de Fin de Semana (LOCF): Arrastre del último precio de
#      cierre del viernes para COLCAP y TES en fines de semana (wday >= 6). Los festivos
#      entre semana no se imputan (permanecen NA). La TRM y Energía no admiten carry-forward.
# ==============================================================================

# 1. Setup ----

## 1.0 Locale ----

# En plataformas Windows, la configuración regional por defecto (ANSI/Codepage 1252)
# puede mutilar o alterar caracteres del idioma español (tildes, eñes). Esta función
# intenta configurar la categoría LC_CTYPE en UTF-8 para garantizar la serialización
# y lectura uniforme de cadenas textuales en todas las plataformas.
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

# Identificación robusta del directorio raíz del repositorio, compatible tanto
# con llamadas desatendidas (Rscript scripts/data/...) como interactivas (RStudio).
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

# Horizonte temporal global (1.400 días calendario: 2022-08-01 a 2026-05-31)
date_start <- as.Date("2022-08-01")
date_end <- as.Date("2026-05-31")

# Fecha de posesión presidencial: 7 de agosto de 2022.
# Los tweets de @petrogustavo anteriores al 7 de agosto de 2022 corresponden a su
# rol como presidente electo y se filtran rigurosamente por diseño de investigación.
presidential_date_start <- as.Date("2022-08-07")

# Controles de integridad de parámetros
stopifnot(
  "date_start debe ser un objeto Date valido no nulo" = inherits(date_start, "Date") && !is.na(date_start),
  "date_end debe ser un objeto Date valido no nulo" = inherits(date_end, "Date") && !is.na(date_end),
  "presidential_date_start debe ser un objeto Date valido no nulo" = inherits(presidential_date_start, "Date") && !is.na(presidential_date_start),
  "date_start debe ser anterior o igual a presidential_date_start" = date_start <= presidential_date_start,
  "presidential_date_start debe ser estrictamente anterior a date_end" = presidential_date_start < date_end
)

corpus_label_opinion <- "Conversación pública sobre Gustavo Petro"
corpus_label_presidente <- "Tweets escritos por @petrogustavo"

financial_series <- c("trm", "colcap", "tes_1y", "tes_5y", "tes_10y")
market_series <- c(financial_series, "energy_spot_price")

## 1.4 Fuentes de mercado documentadas ----

# Metadatos oficiales de las series de mercado procesadas downstream
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

# Escritura atómica y defensiva de archivos CSV creando directorios si no existen
write_csv_safe <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
  invisible(path)
}

# Lectura segura con tipado como character de todas las columnas:
# Justificación metodológica crítica: Los identificadores de Twitter (Snowflake IDs)
# son enteros de 64 bits (~1.8 x 10^18) que exceden la capacidad de representación
# exacta de enteros de coma flotante de doble precisión según IEEE 754 (53 bits de
# mantisa, ~9 x 10^15). Una lectura numérica convencional truncaría los últimos
# dígitos e induciría colisiones espurias en IDs de tweets y usuarios.
read_csv_character <- function(path) {
  stopifnot(
    "El archivo especificado para lectura no existe" = file.exists(path)
  )
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE,
    lazy = FALSE
  )
}

# Reparar secuencias de acentuación mal serializadas en el archivo presidencial legacy.
# Regla de orden estricta: Esta función se ejecuta ÚNICAMENTE después de suprimir
# las URLs (https?://\S+), para evitar corromper identificadores o secuencias de
# escape en enlaces cortos de Twitter.
repair_legacy_twitter_text <- function(x) {
  x |>
    stringr::str_replace_all("[cC]3", "ó") |>
    stringr::str_replace_all("[cC]-", "í") |>
    stringr::str_replace_all("[cC]!", "á") |>
    stringr::str_replace_all("[cC]\\)", "é") |>
    stringr::str_replace_all("[cC]1", "ñ") |>
    stringr::str_replace_all("[cC]:", "ú")
}

# Normalización de rutas relativas a la raíz del repositorio para auditoría portátil
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

# Plantilla de estructura vacía con esquema canónico de tweets
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

# Ingesta, parseo temporal y calibración de zona horaria de archivos de tweets:
# 1. Valida presencia de columnas mínimas obligatorias (id, author_id, created_at, text, lang).
# 2. Parsea timestamp en UTC y convierte formalmente a hora legal colombiana
#    (America/Bogota, UTC-5). Esto es indispensable para evitar que tweets emitidos
#    entre 19:00 y 23:59 hora local queden indexados erróneamente en el día siguiente.
# 3. Filtra caracteres de control ASCII no imprimibles ([\x00-\x08\x0B\x0C\x0E-\x1F\x7F])
#    que rompen tokenizadores en C++ o inducen nulos UTF-8.
# 4. Filtra por ventana temporal analítica y deduplica por (corpus, raw_source, id).
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

    stopifnot(
      "El archivo de tweets carece de columnas requeridas (id, author_id, created_at, text, lang)" =
        length(missing_cols) == 0L
    )

    parsed_time <- suppressWarnings(lubridate::ymd_hms(raw$created_at, tz = "UTC", quiet = TRUE))
    stopifnot(
      "Los timestamps de tweets no pudieron ser parseados como fecha-hora valida" =
        any(!is.na(parsed_time))
    )

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

# Carga de series individuales brutas de mercado generadas por ingest_market.R
read_market_raw_series <- function(series) {
  path <- file.path(raw_market_dir, paste0(series, "_raw.csv"))

  stopifnot(
    "Falta el archivo raw requerido para la serie de mercado" = file.exists(path)
  )

  raw <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)

  stopifnot(
    "Falta columna date en el archivo raw de mercado" = "date" %in% names(raw)
  )

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

# Funciones auxiliares para delimitación de fechas observadas
first_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[min(ok)]
}

last_non_missing_date <- function(date, value) {
  ok <- which(!is.na(value))
  if (length(ok) == 0) as.Date(NA) else date[max(ok)]
}

# 2. Carga de insumos ----

## 2.1 Validacion de rutas y precondiciones de entrada ----

required_dirs <- c(raw_twitter_opinion_dir, raw_twitter_presidente_dir, raw_market_dir)
missing_dirs <- required_dirs[!dir.exists(required_dirs)]

stopifnot(
  "Carpetas raw requeridas no encontradas" = length(missing_dirs) == 0L,
  "Fuente presidencial inexistente en raw/twitter. Debe existir petrogustavo_full.csv o carpetas fallback" =
    file.exists(raw_twitter_presidente_full_path) ||
    dir.exists(raw_twitter_presidente_data_dir) ||
    dir.exists(raw_twitter_presidente_archive_dir)
)

dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

## 2.2 Archivos raw de Twitter y mercado ----

opinion_files <- list.files(
  raw_twitter_opinion_dir,
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = FALSE
)

stopifnot(
  "No se encontraron archivos mensuales de opinion en data/raw/twitter/Opinion sobre Petro/" =
    length(opinion_files) > 0L,
  "Faltan archivos de mercado raw en data/raw/market/" =
    all(file.exists(file.path(raw_market_dir, paste0(market_series, "_raw.csv"))))
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

## 3.1 Corpus de opinion ciudadana ----

# Ingesta de los 46 archivos mensuales de conversación ciudadana en torno a la
# gestión y propuestas presidenciales. Rango: 1 de agosto de 2022 al 31 de mayo de 2026.
# Provee la serie de sentimiento público de referencia.
tweets_opinion <- read_tweet_files(
  files = sort(opinion_files),
  corpus = "opinion",
  corpus_label = corpus_label_opinion,
  raw_source = "opinion",
  start_date = date_start,
  end_date = date_end
)

## 3.2 Corpus presidencial (@petrogustavo) ----

# Ingesta del archivo consolidado y carpetas de respaldo de la cuenta presidencial.
# Justificación metodológica del umbral 2022-08-07: La investidura presidencial
# tuvo lugar el 7 de agosto de 2022. Los mensajes previos corresponden a su condición
# de presidente electo y se filtran rigurosamente (start_date = presidential_date_start)
# para que el corpus presidencial refleje exclusivamente actos de gobierno en funciones.
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

# Deduplicación determinista de fuentes presidenciales por clave compuesta (corpus, id)
tweets_presidente <- dplyr::bind_rows(
  tweets_presidente_full,
  tweets_presidente_data,
  tweets_presidente_archive
) |>
  dplyr::arrange(date, created_at, id) |>
  dplyr::distinct(corpus, id, .keep_all = TRUE)

# Consolidación total de ambos corpus
tweets_all <- dplyr::bind_rows(tweets_opinion, tweets_presidente) |>
  dplyr::arrange(corpus, date, created_at, id)

## 3.3 Master de tweets y pipeline textual en dos capas ----

# Justificación del pipeline lingüístico en dos capas:
# 1. doc_id: Clave primaria global sintética concatenando corpus y Snowflake ID de 64 bits.
# 2. text_original: Copia inmutable del texto original para auditorías lingüísticas y forenses.
# 3. text_topic: Normalización en minúsculas, remoción de URLs, reparación de acentos legados,
#    supresión de @menciones y #hashtags, y conservación de dígitos ([:alnum:]) y caracteres en español.
#    Esencial para modelos temáticos estructurales (STM, KeyATM) donde los números de leyes, reformas
#    o años son portadores de contenido semántico crucial.
# 4. text_clean: Normalización puramente alfabética ([:alpha:]), retirando todo dígito numérico.
#    Esencial para análisis de sentimiento léxico (NRC, Sentometrics, Wordfish) donde números aislados
#    generan falsos positivos o sesgan la densidad de palabras con carga afectiva.
# 5. month: Variable mensual para agregaciones y tablas de resumen temporal.
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

## 4.1 Lectura de series raw y ensamblaje del panel ----

# Grilla cronológica diaria completa (1.400 días calendario: 2022-08-01 a 2026-05-31)
date_frame <- tibble::tibble(date = seq(date_start, date_end, by = "day"))
market_daily <- date_frame

# Unión secuencial (left join) de cada serie descargada en raw sobre la grilla continua
for (series_name in market_series) {
  market_daily <- dplyr::left_join(
    market_daily,
    read_market_raw_series(series_name),
    by = "date"
  )
}

## 4.2 Imputacion de fines de semana financieros y derivaciones ----

market_daily <- market_daily |>
  dplyr::arrange(date)

# 1. Banderas de observación efectiva: TRUE si la serie cotizó ese día
for (series_name in market_series) {
  market_daily[[paste0(series_name, "_observed")]] <- !is.na(market_daily[[series_name]])
}

# 2. Imputación de fin de semana (LOCF) para series financieras bursátiles (COLCAP y TES):
# Los mercados bursátiles cierran sábados y domingos (wday >= 6). Se arrastra el cierre del
# viernes asumiendo continuidad patrimonial.
# Regla de integridad: Los festivos entre semana NO se imputan (permanecen NA) para no inventar
# cotizaciones en días hábiles.
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

# 3. Series energéticas y spread soberano:
# - El precio spot de energía física opera 7 días continuos; no admite carry-forward.
# - La pendiente de la curva de rendimientos es el spread tes_slope_10y_1y = tes_10y - tes_1y (% E.A.).
market_master <- market_daily |>
  dplyr::mutate(
    energy_spot_price_carried_forward = FALSE,
    tes_slope_10y_1y = tes_10y - tes_1y,
    tes_slope_10y_1y_observed = tes_10y_observed & tes_1y_observed,
    tes_slope_10y_1y_carried_forward = tes_10y_carried_forward | tes_1y_carried_forward
  )

## 4.3 Fuentes y tablas de cobertura para auditoria ----

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

# 5. Validaciones finales de esquema e integridad ----

## 5.1 Columnas y esquema contractual ----

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

market_master <- market_master |>
  dplyr::select(dplyr::all_of(market_cols))

stopifnot(
  "El esquema de tweets_master no coincide exactamente con el contrato master_tweet_cols" =
    identical(names(tweets_master), master_tweet_cols),
  "El esquema de market_master no coincide exactamente con el contrato market_cols" =
    identical(names(market_master), market_cols)
)

## 5.2 Controles stopifnot() de integridad de tweets_master ----

stopifnot(
  "tweets_master no contiene observaciones (nrow == 0)" =
    nrow(tweets_master) > 0L,
  "tweets_master contiene identificadores id o author_id que no son de tipo character" =
    is.character(tweets_master$id) && is.character(tweets_master$author_id),
  "tweets_master contiene identificadores id o doc_id vacios o nulos" =
    !any(is.na(tweets_master$id) | tweets_master$id == "") &&
    !any(is.na(tweets_master$doc_id) | tweets_master$doc_id == ""),
  "tweets_master contiene claves primarias duplicadas (corpus, id)" =
    !anyDuplicated(tweets_master[c("corpus", "id")]),
  "tweets_master contiene identificadores doc_id duplicados" =
    !anyDuplicated(tweets_master$doc_id),
  "tweets_master contiene valores no autorizados en la columna corpus (solo 'opinion' o 'presidente')" =
    all(tweets_master$corpus %in% c("opinion", "presidente")),
  "Los tweets presidenciales contienen fechas anteriores a la posesion constitucional (2022-08-07)" =
    all(tweets_master$date[tweets_master$corpus == "presidente"] >= presidential_date_start),
  "tweets_master contiene fechas fuera del horizonte temporal de estudio [2022-08-01, 2026-05-31]" =
    all(!is.na(tweets_master$date) & tweets_master$date >= date_start & tweets_master$date <= date_end),
  "tweets_master no preserva correctamente los campos de texto como character" =
    is.character(tweets_master$text_original) && is.character(tweets_master$text_topic) && is.character(tweets_master$text_clean)
)

## 5.3 Controles stopifnot() de integridad de market_master ----

numeric_market_cols <- setdiff(market_value_cols, "date")
logical_market_cols <- market_flag_cols

stopifnot(
  "market_master no contiene observaciones (nrow == 0)" =
    nrow(market_master) > 0L,
  "market_master debe contener exactamente 1.400 fechas calendario continuas" =
    nrow(market_master) == as.integer(date_end - date_start + 1L),
  "market_master contiene fechas duplicadas o no estrictamente ordenadas" =
    !anyDuplicated(market_master$date) && all(diff(market_master$date) == 1L),
  "Las series de mercado en market_master deben ser de tipo numerico" =
    all(vapply(market_master[numeric_market_cols], is.numeric, logical(1))),
  "Las banderas de observacion y arrastre en market_master deben ser de tipo logico" =
    all(vapply(market_master[logical_market_cols], is.logical, logical(1))),
  "market_master contiene al menos una serie completamente vacia (todo NA)" =
    !any(vapply(market_master[numeric_market_cols], function(x) all(is.na(x)), logical(1)))
)

# 6. Exportacion y saneamiento ----

## 6.1 Escritura de contratos maestros ----

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

## 6.3 Resumen final y reporte de integridad ----

message("Filas tweets_master: ", nrow(tweets_master))
print(tweets_master |> dplyr::count(corpus, name = "filas"))
message("Rango tweets: ", min(tweets_master$date), " a ", max(tweets_master$date))
message("Filas market_master: ", nrow(market_master))
message("Rango mercado: ", min(market_master$date), " a ", max(market_master$date))
message("Output tweets: ", tweets_master_path)
message("Output mercado: ", market_master_path)
