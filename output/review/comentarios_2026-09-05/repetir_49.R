# QA only: this script is not sourced by the notebook.
# Usage: Rscript --vanilla validar_resultados.R ENV_RDATA PREFIX_RDATA ORIGINAL_RMD OUTPUT_CSV
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L)

# Cargar las dependencias y preferencias de la versión que produjo el entorno.
# El cuerpo de las 49 comprobaciones históricas se conserva sin modificaciones.
qa_notebook <- Sys.getenv("CUADERNO_VALIDACION", "notebooks/español/Cuaderno_Paper_Español.Rmd")
qa_lines <- readLines(qa_notebook, warn = FALSE)
for (qa_start in which(startsWith(qa_lines, "```{r librerias-"))) {
  qa_end <- qa_start + which(trimws(qa_lines[(qa_start + 1):length(qa_lines)]) == "```")[1]
  eval(parse(text = qa_lines[(qa_start + 1):(qa_end - 1)]), envir = .GlobalEnv)
}
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(knitr))
current <- new.env(parent = globalenv())
prior <- new.env(parent = globalenv())
if (grepl("\\.rds$", args[1])) current <- readRDS(args[1]) else load(args[1], envir = current)
load(args[2], envir = prior)
checks <- list()
check <- function(name, passed, detail = "") {
  checks[[length(checks) + 1L]] <<- data.frame(check = name, passed = isTRUE(passed), detail = detail)
}
eq <- function(x, y) isTRUE(all.equal(x, y, tolerance = 1e-10, check.attributes = TRUE))
for (name in c('tweets_text', 'tweets_text_analysis', 'tweets_all_normalized',
  'daily_sentiment', 'daily_sentiment_by_corpus', 'model_dataset',
  'model_dataset_by_corpus', 'nrc_initial', 'market_daily')) {
  check(paste('insumo protegido', name), eq(current[[name]], prior[[name]]))
}
# Compare source expressions of the original notebook with the reorganized model outputs.
original <- readLines(args[3], warn = FALSE)
get_code <- function(label) {
  start <- which(original == paste0('```{r ', label, '}'))
  stopifnot(length(start) == 1)
  end <- start + which(grepl('^```\\s*$', original[(start + 1):length(original)]))[1]
  original[(start + 1):(end - 1)]
}
reference <- new.env(parent = current)
reference$model_dataset <- current$model_dataset_ipi
reference$tables_dir <- tempfile('reference-tables-')
dir.create(reference$tables_dir)
reference$recompute_heavy <- TRUE
reference$ready_econometrics_tables_01 <- TRUE
suppressWarnings(eval(parse(text = get_code('econometrics-tables-01-calculo-01')), envir = reference))
check('ADF equivalente al código original', eq(current$stationarity, reference$stationarity))
check('Granger principal: 40 combinaciones equivalentes', eq(current$granger_all, reference$granger_all))
check('VAR: coeficientes originales', eq(coef(current$fit_var), coef(reference$fit_var)))
check('VAR: residuos originales', eq(residuals(current$fit_var), residuals(reference$fit_var)))
check('VAR: muestra y orden originales', identical(current$fit_var$obs, reference$fit_var$obs) && current$fit_var$p == 2)
expr <- parse(text = get_code('econometrics-tables-02'))
# First five statements compute the complete per-corpus results; later statements only format/export.
for (e in expr[seq_len(5)]) suppressWarnings(eval(e, envir = reference))
check('Granger por corpus: combinaciones equivalentes', eq(current$granger_by_corpus, reference$granger_by_corpus))
# Recompute the original IPI and events without modifying inherited inputs.
suppressWarnings(eval(parse(text = get_code('ipi-index')), envir = reference))
check('IPI temático: fórmula original', eq(current$ipi_daily, reference$ipi_daily))
check('Panel actualizado equivalente sin sobrescritura', eq(current$model_dataset_ipi, reference$model_dataset))
suppressWarnings(eval(parse(text = get_code('event-study')), envir = reference))
check('Eventos, ventanas y retornos equivalentes', eq(current$eventos_extremos_ipi, reference$eventos_extremos_ipi))
# NRC reuse must reproduce scores and row order of the analytical subset.
index <- match(current$nrc_doc$doc_id, current$nrc_initial$doc_id)
check('NRC: correspondencia exacta por documento', !anyNA(index) &&
  eq(as.data.frame(current$nrc_doc[current$sentiment_cols]),
     as.data.frame(current$nrc_initial[index, current$sentiment_cols])))
check('NRC: orden de documentos', identical(current$nrc_doc$doc_id, current$tweets_text_analysis$doc_id))
# Verify the rolling window independently with explicit per-series seven-date sums.
series <- current$sento_long |>
  group_by(lexicon, feature, time_weight) |>
  arrange(date, .by_group = TRUE) |>
  mutate(expected = vapply(seq_along(value), function(i) {
    if (i < 7) NA_real_ else sum(value[(i - 6):i]) / 7
  }, numeric(1))) |>
  ungroup()
check('Media móvil: siete fechas de cada serie', eq(series$value_ma7, series$expected))
raw_long <- current$sento_measures_raw |>
  pivot_longer(-date, names_to = 'measure', values_to = 'value') |>
  separate(measure, into = c('lexicon', 'feature', 'time_weight'), sep = '--', fill = 'right', extra = 'merge') |>
  arrange(lexicon, feature, time_weight, date)
check('Sentometrics: valores diarios intactos', eq(series$value, raw_long$value))
check('Calendario principal diario completo', all(diff(current$model_dataset_ipi$date) == 1))
for (h in c(1, 3, 5, 7)) {
  panel <- current$model_dataset_ipi
  actual <- current$event_base[[paste0('trm_h', h)]]
  expected <- (panel$trm[match(panel$date + h, panel$date)] - panel$trm) / panel$trm
  check(paste('Horizonte TRM por fecha', h), eq(actual, expected))
}
check('Diez eventos por cada criterio', all(table(current$eventos_extremos_ipi$evento) == 10))
check('Sin duplicados dentro del criterio de evento', !anyDuplicated(current$eventos_extremos_ipi[c('evento', 'date')]))
check('160 contrastes completos conservados', nrow(current$granger_complete) == 160L)
check('Estado IRF veraz', current$method_status$estado[current$method_status$bloque == 'IRF'] == 'no implementada')
check('spaCy: clase nativa conservada', inherits(current$parsed_spacy, 'spacyr_parsed'))
check('spaCy: extracción efectiva de entidades y frases', nrow(current$entity_raw) > 0 && nrow(current$noun_raw) > 0)
check('spaCy: identificadores visuales únicos', !anyDuplicated(current$spacy_node_attributes$id))
# Older exported tables may be stale. Re-evaluate the original expressions with the same inputs.
for (spec in list(
  c('social-entities', 'hashtags', 'mentions', 'top_hashtags', 'top_mentions'),
  c('network-edge-tables-01', 'mention_edges', 'cooc_edges'),
  c('network-ladal-mentions-by-corpus-01', 'mention_edges_by_corpus'),
  c('network-ladal-theme-entity-01', 'theme_entity_edges')
)) {
  eval(parse(text=get_code(spec[1])), envir=reference)
  for (name in spec[-1]) check(paste('Código original recalculado:', name), eq(current[[name]], reference[[name]]))
}
eval(parse(text=get_code('sentometrics-section-01')), envir=reference)
for (name in c('sento_corpus_df', 'sento_measures_raw', 'sentometrics_corpus',
               'sentometrics_theme', 'sentometrics_paz')) {
  check(paste('Sentometrics original recalculado:', name), eq(current[[name]], reference[[name]]))
}
check('Colocaciones: bigramas recuperados', nrow(current$colloc_bi_robust) > 0 &&
  all(str_count(current$colloc_bi_robust$bigram, '_') == 1))
check('Colocaciones: trigramas recuperados', nrow(current$colloc_tri_robust) > 0 &&
  all(str_count(current$colloc_tri_robust$trigram, '_') == 2))
result <- bind_rows(checks)
write.csv(result, args[4], row.names = FALSE, na = '')
print(result, row.names = FALSE)
if (!all(result$passed)) quit(status = 1L)
