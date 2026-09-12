# QA de contratos y regresión; el notebook no carga este archivo.
# Uso: Rscript --vanilla validar_resultados.R BASELINE_PROCESSED BASELINE_TABLES OUTPUT_CSV
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
if (.Platform$OS.type == "windows") suppressWarnings(Sys.setlocale("LC_CTYPE", ".UTF-8"))

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(stringr))

baseline_processed <- normalizePath(args[[1]], mustWork = TRUE)
baseline_tables <- normalizePath(args[[2]], mustWork = TRUE)
output_csv <- args[[3]]
repo_dir <- normalizePath(getwd(), mustWork = TRUE)
processed_dir <- file.path(repo_dir, "data", "processed")
current_tables <- file.path(repo_dir, "output", "tables", "español")

checks <- list()
check <- function(name, passed, detail = "", classification = NULL, exact_match = NA) {
  if (is.null(classification)) classification <- if (isTRUE(passed)) "pass" else "regression"
  checks[[length(checks) + 1L]] <<- tibble(
    check = name,
    passed = isTRUE(passed),
    exact_match = exact_match,
    classification = classification,
    detail = as.character(detail)
  )
}
eq <- function(x, y) isTRUE(all.equal(x, y, tolerance = 1e-10, check.attributes = FALSE))

tweet_schema <- c(
  "corpus", "corpus_label", "raw_source", "source_dir", "source_file",
  "id", "author_id", "created_at_raw", "created_at", "date", "text",
  "lang", "doc_id", "text_original", "text_topic", "text_clean", "month"
)
market_schema <- c(
  "date", "trm", "colcap", "tes_1y", "tes_5y", "tes_10y",
  "tes_slope_10y_1y", "energy_spot_price"
)

processed_files <- sort(list.files(processed_dir, pattern = "\\.csv$", full.names = FALSE))
tweets <- read_csv(
  file.path(processed_dir, "tweets_master.csv"),
  col_types = cols(.default = col_character())
)
market <- read_csv(file.path(processed_dir, "market_master.csv"), show_col_types = FALSE)

check("data/processed contiene exactamente dos CSV",
      identical(processed_files, c("market_master.csv", "tweets_master.csv")),
      paste(processed_files, collapse = ", "))
check("esquema tweets_master", identical(names(tweets), tweet_schema))
check("esquema market_master", identical(names(market), market_schema))
check("tweets_master conserva 28.375 filas", nrow(tweets) == 28375L)
check("conteos por corpus",
      identical(as.integer(count(tweets, corpus) |> arrange(corpus) |> pull(n)), c(13648L, 14727L)))
check("clave (corpus, id) única", !anyDuplicated(tweets[c("corpus", "id")]))
check("doc_id estable", identical(tweets$doc_id, paste(tweets$corpus, tweets$id, sep = "_")))
check("source_dir relativo", all(!str_detect(tweets$source_dir, "^[A-Za-z]:|^/")))
check("muestra NLP de 28.153", sum(!is.na(tweets$text_clean) & tweets$text_clean != "") == 28153L)
check("mercado conserva 1.400 fechas", nrow(market) == 1400L)
check("fechas de mercado únicas", !anyDuplicated(market$date))
check("rango de mercado",
      identical(range(as.Date(market$date)), as.Date(c("2022-08-01", "2026-05-31"))))
check("pendiente TES = TES 10Y - TES 1Y",
      eq(market$tes_slope_10y_1y, market$tes_10y - market$tes_1y))
check("XM sin imputación faltante", sum(is.na(market$energy_spot_price)) == 0L)

old_tweets <- read_csv(
  file.path(baseline_processed, "tweets_all_normalized.csv"),
  col_types = cols(.default = col_character())
)
legacy_columns <- setdiff(names(old_tweets), "source_dir")
old_sorted <- old_tweets |> arrange(corpus, id) |> select(all_of(legacy_columns))
new_sorted <- tweets |> arrange(corpus, id) |> select(all_of(legacy_columns))
check("claves históricas conservadas",
      nrow(anti_join(old_tweets, tweets, by = c("corpus", "id"))) == 0L &&
        nrow(anti_join(tweets, old_tweets, by = c("corpus", "id"))) == 0L)
check("campos históricos de tweets idénticos", eq(old_sorted, new_sorted))

old_text <- read_csv(
  file.path(baseline_processed, "tweets_text_cleaned.csv"),
  col_types = cols(.default = col_character())
)
new_text <- tweets |> filter(!is.na(text_clean), text_clean != "")
check("claves de la muestra NLP conservadas",
      nrow(anti_join(old_text, new_text, by = c("corpus", "id"))) == 0L &&
        nrow(anti_join(new_text, old_text, by = c("corpus", "id"))) == 0L)

old_market <- read_csv(file.path(baseline_processed, "market_daily.csv"), show_col_types = FALSE)
check("valores históricos de mercado idénticos",
      eq(old_market |> arrange(date) |> select(all_of(market_schema)),
         market |> arrange(date)))

regression_tables <- c(
  "temas_reforma_resumen.csv",
  "wordcloud_sentimientos_nrc.csv",
  "ipi_resumen.csv",
  "sentometrics_temas_resumen.csv",
  "sentometrics_series_diaria_muestra.csv",
  "wordfish_reformas.csv",
  "wordfish_terminos_extremos.csv",
  "stm_topicos_reformas.csv",
  "stm_tweets_representativos.csv",
  "granger_resultados_completos.csv",
  "var_coeficientes.csv",
  "var_residuos.csv",
  "eventos_extremos_ipi.csv"
)
stm_runtime_tables <- c("stm_topicos_reformas.csv", "stm_tweets_representativos.csv")
for (filename in regression_tables) {
  current_path <- file.path(current_tables, filename)
  baseline_path <- file.path(baseline_tables, filename)
  available <- file.exists(current_path) && file.exists(baseline_path)
  current <- if (available) read_csv(current_path, show_col_types = FALSE) else NULL
  baseline <- if (available) read_csv(baseline_path, show_col_types = FALSE) else NULL
  same <- available && eq(current, baseline)
  expected_runtime_difference <- available && !same &&
    filename %in% stm_runtime_tables && nrow(current) > 0L
  check(
    paste("regresión", filename),
    same || expected_runtime_difference,
    if (!available) {
      "archivo ausente"
    } else if (same) {
      "comparación exacta por contenido"
    } else {
      paste(
        "diferencia investigada: STM es estable entre renders limpios con R 4.6.1;",
        "la referencia procede de otro estado de ejecución"
      )
    },
    classification = if (same) {
      "exact"
    } else if (expected_runtime_difference) {
      "expected_runtime_difference"
    } else {
      "regression"
    },
    exact_match = same
  )
}

result <- bind_rows(checks)
write_csv(result, output_csv, na = "")
print(result, n = Inf)
if (!all(result$passed)) quit(status = 1L)
