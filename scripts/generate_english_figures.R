#!/usr/bin/env Rscript
# ==============================================================================
# Script: generate_english_figures.R
# Purpose: Reproduce the 10 core publication figures with high-quality English
#          typography, labels, legends, and styling.
# Outputs: output/figures/English/ and paper/figures/English/
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(lubridate)
  library(forcats)
  library(ggwordcloud)
  library(rugarch)
  library(rmgarch)
})

# Setup output directories
out_en <- "output/figures/English"
paper_en <- "paper/figures/English"
dir.create(file.path(out_en, "econometria"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(paper_en, "econometria"), recursive = TRUE, showWarnings = FALSE)

cat("===================================================================\n")
cat("Generating English Publication Figures\n")
cat("===================================================================\n")

# ------------------------------------------------------------------------------
# 1. Figure 1: Plutchik Wheel of Emotions (English)
# ------------------------------------------------------------------------------
cat("\n[1/10] Setting up Figure 1: Plutchik Emotion Wheel...\n")
src_plutchik <- "paper/español/figures/plutchik_rueda_emociones_en.png"
if (file.exists(src_plutchik)) {
  file.copy(src_plutchik, file.path(paper_en, "figura1_plutchik.png"), overwrite = TRUE)
  file.copy(src_plutchik, file.path(out_en, "figura1_plutchik.png"), overwrite = TRUE)
  file.copy(src_plutchik, file.path(paper_en, "plutchik_rueda_emociones_en.png"), overwrite = TRUE)
  file.copy(src_plutchik, file.path(out_en, "plutchik_rueda_emociones_en.png"), overwrite = TRUE)
  cat("  -> Copied successfully.\n")
} else {
  warning("Source Plutchik English wheel not found at ", src_plutchik)
}

# ------------------------------------------------------------------------------
# Load Master Datasets
# ------------------------------------------------------------------------------
cat("\nLoading master datasets...\n")
tweets_master <- read_csv("data/processed/tweets_master.csv", col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
  mutate(
    date = as.Date(date),
    month = as.Date(month)
  )

market_master <- read_csv("data/processed/market_master.csv", show_col_types = FALSE) %>%
  mutate(date = as.Date(date))

# ------------------------------------------------------------------------------
# 2. Figure 4: Monthly Volume Comparison by Corpus
# ------------------------------------------------------------------------------
cat("\n[2/10] Generating Figure 4: Monthly Volume Comparison by Corpus...\n")
corpus_volume_monthly <- tweets_master %>%
  mutate(month = floor_date(date, "month")) %>%
  group_by(corpus, month) %>%
  summarise(tweets_n = n(), .groups = "drop") %>%
  mutate(serie = if_else(corpus == "presidente", "Presidential Posts (@petrogustavo)", "Public Opinion Sample")) %>%
  select(month, serie, tweets_n) %>%
  pivot_wider(names_from = serie, values_from = tweets_n, values_fill = 0) %>%
  arrange(month)

max_opinion <- max(corpus_volume_monthly[["Public Opinion Sample"]], na.rm = TRUE)
max_petro <- max(corpus_volume_monthly[["Presidential Posts (@petrogustavo)"]], na.rm = TRUE)
axis_factor <- if (is.finite(max_opinion) && is.finite(max_petro) && max_opinion > 0 && max_petro > 0) max_opinion / max_petro else 1

p_vol <- corpus_volume_monthly %>%
  ggplot(aes(x = month)) +
  geom_col(aes(y = `Public Opinion Sample`, fill = "Public Opinion Sample"), width = 24, alpha = 0.72) +
  geom_line(aes(y = `Presidential Posts (@petrogustavo)` * axis_factor, color = "Presidential Posts (@petrogustavo)"), linewidth = 0.95) +
  geom_point(aes(y = `Presidential Posts (@petrogustavo)` * axis_factor, color = "Presidential Posts (@petrogustavo)"), size = 1.9) +
  scale_fill_manual(values = c("Public Opinion Sample" = "#2f6f73")) +
  scale_color_manual(values = c("Presidential Posts (@petrogustavo)" = "#8f5d2c")) +
  scale_y_continuous(
    name = "Public Opinion Posts",
    labels = comma,
    sec.axis = sec_axis(~ . / axis_factor, name = "Presidential Posts (@petrogustavo)", labels = comma)
  ) +
  labs(
    title = "Monthly Post Volume Comparison by Corpus",
    subtitle = "Dual vertical axis comparing monthly conversational intensity without obscuring presidential dynamics",
    x = NULL, fill = NULL, color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(out_en, "comparacion_corpus_volumen.png"), p_vol, width = 11, height = 5.8, dpi = 300)
ggsave(file.path(paper_en, "comparacion_corpus_volumen.png"), p_vol, width = 11, height = 5.8, dpi = 300)
cat("  -> Figure 4 saved.\n")

# ------------------------------------------------------------------------------
# Daily Presidential Post Frequency (EDA)
# ------------------------------------------------------------------------------
cat("\nGenerating EDA: Daily Presidential Post Frequency...\n")
petro_daily <- tweets_master %>%
  filter(corpus == "presidente") %>%
  count(date, name = "tweets") %>%
  complete(date = seq.Date(min(date), max(date), by = "day"), fill = list(tweets = 0)) %>%
  mutate(tweets_ma7 = zoo::rollmean(tweets, k = 7, fill = NA, align = "center"))

p_petro_daily <- ggplot(petro_daily, aes(x = date)) +
  geom_col(aes(y = tweets), fill = "#8f5d2c", alpha = 0.45, width = 1) +
  geom_line(aes(y = tweets_ma7), color = "#2f6f73", linewidth = 0.8, na.rm = TRUE) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "EDA: Daily Frequency of Presidential Posts (@petrogustavo)",
    subtitle = "Daily post count bars and centered 7-day moving average",
    x = NULL,
    y = "Daily Posts"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path(out_en, "eda_petro_tweets_diarios.png"), p_petro_daily, width = 11, height = 5.8, dpi = 300)
ggsave(file.path(paper_en, "eda_petro_tweets_diarios.png"), p_petro_daily, width = 11, height = 5.8, dpi = 300)
cat("  -> eda_petro_tweets_diarios.png saved.\n")

# ------------------------------------------------------------------------------
# 3. Figure 6: Reform Themes Distribution
# ------------------------------------------------------------------------------
cat("\n[3/10] Generating Figure 6: Reform Themes Distribution...\n")
themes_raw <- read_csv("output/tables/español/temas_reforma_resumen.csv", show_col_types = FALSE)

theme_dict <- c(
  "institucionalidad" = "Institutions & Governance",
  "seguridad" = "Security & Defense",
  "internacional" = "Foreign Policy",
  "salud" = "Health Reform",
  "laboral" = "Labor Reform",
  "economia" = "Economy & Growth",
  "energia_ambiente" = "Environment & Transition",
  "paz_total" = "Total Peace",
  "tributaria" = "Tax Reform",
  "pensional" = "Pension Reform",
  "energia_tarifas" = "Energy Tariffs",
  "constituyente" = "Constituent Assembly",
  "reforma_general" = "General Reforms"
)

corpus_dict <- c(
  "Conversación pública sobre Gustavo Petro" = "Public Opinion Conversation",
  "Tweets escritos por @petrogustavo" = "Presidential Posts (@petrogustavo)"
)

themes_en <- themes_raw %>%
  mutate(
    reform_theme_en = recode(reform_theme, !!!theme_dict),
    corpus_label_en = recode(corpus_label, !!!corpus_dict)
  ) %>%
  mutate(reform_theme_en = fct_reorder(reform_theme_en, tweets))

p_themes <- themes_en %>%
  ggplot(aes(x = tweets, y = reform_theme_en, fill = reform_theme_en)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = percent(participacion, accuracy = 0.1)), hjust = -0.05, size = 3.5) +
  facet_wrap(~ corpus_label_en, ncol = 1, scales = "free_x") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.18)), labels = comma) +
  labs(
    title = "Relative Weight of Discursive Themes by Corpus",
    x = "Number of Posts", y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold", size = 11))

ggsave(file.path(out_en, "temas_reforma_resumen.png"), p_themes, width = 8.5, height = 6.5, dpi = 300)
ggsave(file.path(paper_en, "temas_reforma_resumen.png"), p_themes, width = 8.5, height = 6.5, dpi = 300)
cat("  -> Figure 6 saved.\n")

# ------------------------------------------------------------------------------
# 4. Figure 3: Wordcloud by NRC Sentiment Category
# ------------------------------------------------------------------------------
cat("\n[4/10] Generating Figure 3: Wordcloud by NRC Sentiment...\n")
wc_raw <- read_csv("output/tables/español/wordcloud_sentimientos_nrc.csv", show_col_types = FALSE)

sent_dict <- c(
  "Alegría" = "Joy",
  "Ira" = "Anger",
  "Miedo" = "Fear",
  "Tristeza" = "Sadness",
  "Confianza" = "Trust",
  "Sorpresa" = "Surprise",
  "Anticipación" = "Anticipation",
  "Disgusto" = "Disgust",
  "Positivo" = "Positive",
  "Negativo" = "Negative"
)

wc_en <- wc_raw %>%
  mutate(sentimiento_en = recode(sentimiento, !!!sent_dict)) %>%
  group_by(sentimiento_en) %>%
  slice_max(frecuencia, n = 18, with_ties = FALSE) %>%
  mutate(
    peso_visual = if (max(frecuencia, na.rm = TRUE) == min(frecuencia, na.rm = TRUE)) {
      rep(1, n())
    } else {
      scales::rescale(frecuencia, to = c(0.22, 1))
    }
  ) %>%
  ungroup()

p_wc <- ggplot(wc_en, aes(label = termino, size = peso_visual, color = peso_visual)) +
  geom_text_wordcloud_area(
    eccentricity = 0.65, rstep = 0.008, tstep = 0.015,
    max_steps = 60, grid_size = 2, grid_margin = 4,
    seed = 2026, rm_outside = TRUE
  ) +
  scale_size_area(max_size = 8.5, guide = "none") +
  scale_color_gradient(low = "#7a6f57", high = "#2f6f73", guide = "none") +
  facet_wrap(~ sentimiento_en, scales = "free") +
  labs(
    title = "Word Clouds by NRC Sentiment Category",
    subtitle = "Most frequent Spanish terms associated with each NRC emotional dimension in presidential discourse"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text = element_blank(), axis.title = element_blank(),
    panel.grid = element_blank(), strip.text = element_text(face = "bold", size = 10)
  )

ggsave(file.path(out_en, "wordcloud_sentimientos_nrc.png"), p_wc, width = 12, height = 9, dpi = 300)
ggsave(file.path(paper_en, "wordcloud_sentimientos_nrc.png"), p_wc, width = 12, height = 9, dpi = 300)
cat("  -> Figure 3 saved.\n")

# ------------------------------------------------------------------------------
# Daily NRC & IPI Computation for Presidential Corpus
# ------------------------------------------------------------------------------
cat("\nComputing Daily NRC & IPI series for presidential corpus...\n")
daily_cache <- "data/processed/daily_nrc_by_corpus.csv"

if (file.exists(daily_cache)) {
  daily_nrc_by_corpus <- read_csv(daily_cache, show_col_types = FALSE)
} else {
  clean_tweets <- tweets_master %>%
    filter(!is.na(text_clean), text_clean != "")
  
  cat("  Running syuzhet::get_nrc_sentiment on", nrow(clean_tweets), "texts (approx 2 mins)...\n")
  nrc_scores <- syuzhet::get_nrc_sentiment(clean_tweets$text_clean, lang = "spanish")
  nrc_doc <- bind_cols(clean_tweets %>% select(doc_id, corpus, corpus_label, date), as_tibble(nrc_scores))
  
  emotions_all <- c("anger", "anticipation", "disgust", "fear", "joy", "sadness", "surprise", "trust")
  daily_nrc_by_corpus <- nrc_doc %>%
    group_by(corpus, corpus_label, date) %>%
    summarise(
      tweets_n = n(),
      across(all_of(c(emotions_all, "negative", "positive")), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    mutate(polaridad = positive - negative)
  
  write_csv(daily_nrc_by_corpus, daily_cache)
}

daily_nrc_pres <- daily_nrc_by_corpus %>%
  filter(corpus == "presidente")

# ------------------------------------------------------------------------------
# 5. Figure 2: Daily NRC Emotions Over Time
# ------------------------------------------------------------------------------
cat("\n[5/10] Generating Figure 2: Daily NRC Emotions Time Series...\n")
emotion_dict <- c(
  "anger" = "Anger",
  "anticipation" = "Anticipation",
  "disgust" = "Disgust",
  "fear" = "Fear",
  "joy" = "Joy",
  "sadness" = "Sadness",
  "surprise" = "Surprise",
  "trust" = "Trust"
)

emotion_long_en <- daily_nrc_pres %>%
  select(date, anger, anticipation, disgust, fear, joy, sadness, surprise, trust) %>%
  pivot_longer(-date, names_to = "emocion", values_to = "conteo") %>%
  mutate(Emotion = recode(emocion, !!!emotion_dict))

p_emo <- emotion_long_en %>%
  ggplot(aes(x = date, y = conteo, color = Emotion)) +
  geom_line(linewidth = 0.45, alpha = 0.8) +
  labs(
    title = "NRC Emotions Over Time (Presidential Discourse)",
    subtitle = "Daily word frequencies across the eight basic Plutchik emotional dimensions in @petrogustavo posts",
    x = NULL, y = "Daily Word Count", color = "Emotion"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right")

ggsave(file.path(out_en, "sentimiento_emociones_diarias.png"), p_emo, width = 10, height = 5.5, dpi = 300)
ggsave(file.path(paper_en, "sentimiento_emociones_diarias.png"), p_emo, width = 10, height = 5.5, dpi = 300)
cat("  -> Figure 2 saved.\n")

# ------------------------------------------------------------------------------
# 6. Figure 5: Daily Informational Pressure Index (IPI)
# ------------------------------------------------------------------------------
cat("\n[6/10] Generating Figure 5: Daily IPI Time Series...\n")
ipi_daily <- daily_nrc_pres %>%
  mutate(
    sentimiento_promedio_diario = if_else(tweets_n > 0, polaridad / tweets_n, NA_real_),
    sentimiento_estandarizado = as.numeric(scale(sentimiento_promedio_diario)),
    volumen_estandarizado = as.numeric(scale(log1p(tweets_n))),
    ipi = sentimiento_estandarizado * volumen_estandarizado
  )

p_ipi <- ipi_daily %>%
  ggplot(aes(x = date, y = ipi)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "#999999") +
  geom_line(color = "#4a5d8f", linewidth = 0.55, na.rm = TRUE) +
  geom_smooth(method = "loess", se = FALSE, color = "#8f5d2c", linewidth = 0.7, na.rm = TRUE) +
  labs(
    title = "Daily Informational Pressure Index (IPI)",
    subtitle = "Combines standardized average daily tone with communicative intensity for @petrogustavo",
    x = NULL, y = "IPI"
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path(out_en, "ipi_serie_diaria.png"), p_ipi, width = 10, height = 5, dpi = 300)
ggsave(file.path(paper_en, "ipi_serie_diaria.png"), p_ipi, width = 10, height = 5, dpi = 300)
cat("  -> Figure 5 saved.\n")

# ------------------------------------------------------------------------------
# 7. Figure 8A: Granger TRM & COLCAP P-Values
# ------------------------------------------------------------------------------
cat("\n[7/10] Generating Figure 8A: Granger TRM and COLCAP P-Values...\n")
granger_raw <- read_csv("output/tables/español/granger_resultados_completos.csv", show_col_types = FALSE)

resp_dict <- c(
  "ret_trm" = "TRM",
  "ret_colcap" = "COLCAP",
  "diff_tes_10y" = "TES 10Y Yield",
  "diff_tes_slope" = "TES Yield Slope"
)

pred_dict <- c(
  "polaridad" = "Polarity",
  "ipi" = "IPI"
)

granger_plot_data_en <- granger_raw %>%
  filter(!is.na(p_value), predictor %in% c("polaridad", "ipi")) %>%
  mutate(
    response_en = recode(response, !!!resp_dict),
    predictor_en = recode(predictor, !!!pred_dict)
  )

p_granger_main <- granger_plot_data_en %>%
  ggplot(aes(x = lag, y = p_value, color = response_en)) +
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "#b44b4b") +
  geom_line(na.rm = TRUE) +
  geom_point(size = 2, na.rm = TRUE) +
  facet_wrap(~predictor_en, ncol = 2) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Granger Causality P-Values across Lags and Discursive Predictors",
    subtitle = "Dashed red line indicates nominal significance at 5% (none survive Benjamini-Hochberg FDR correction)",
    x = "Lag (Trading Sessions)", y = "Nominal P-Value", color = "Financial Response"
  ) +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold", size = 11), legend.position = "bottom")

ggsave(file.path(out_en, "granger_trm_colcap.png"), p_granger_main, width = 11, height = 7, dpi = 300)
ggsave(file.path(paper_en, "granger_trm_colcap.png"), p_granger_main, width = 11, height = 7, dpi = 300)
cat("  -> Figure 8A saved.\n")

# ------------------------------------------------------------------------------
# 8. Figure 8B: Granger 112 Presidential Emotions Grid
# ------------------------------------------------------------------------------
cat("\n[8/10] Generating Figure 8B: Granger Presidential Emotions Grid...\n")
pred_emo_dict <- c(
  "z_anger" = "Anger",
  "z_fear" = "Fear",
  "z_joy" = "Joy",
  "z_negative" = "Negativity",
  "z_positive" = "Positivity"
)

granger_emo_data_en <- granger_raw %>%
  filter(!is.na(p_value), predictor %in% names(pred_emo_dict)) %>%
  mutate(
    response_en = recode(response, !!!resp_dict),
    predictor_en = recode(predictor, !!!pred_emo_dict)
  )

p_granger_emo <- granger_emo_data_en %>%
  ggplot(aes(x = lag, y = p_value, color = response_en)) +
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "#b44b4b") +
  geom_line(na.rm = TRUE) + geom_point(size = 1.8, na.rm = TRUE) +
  facet_wrap(~predictor_en, ncol = 3) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Granger Causality P-Values for Presidential Emotional Signals",
    subtitle = "Testing temporal precedence across lags 1 to 4 against Colombian financial assets",
    x = "Lag (Trading Sessions)", y = "Nominal P-Value", color = "Financial Response"
  ) +
  theme_minimal(base_size = 11) +
  theme(strip.text = element_text(face = "bold", size = 10), legend.position = "bottom")

ggsave(file.path(out_en, "granger_presidencial_emociones.png"), p_granger_emo, width = 11, height = 7, dpi = 300)
ggsave(file.path(paper_en, "granger_presidencial_emociones.png"), p_granger_emo, width = 11, height = 7, dpi = 300)
cat("  -> Figure 8B saved.\n")

# ------------------------------------------------------------------------------
# 9. Figure 9: Event Study Cumulative Response Heatmap
# ------------------------------------------------------------------------------
cat("\n[9/10] Generating Figure 9: Event Study Cumulative Response Heatmap...\n")
es_raw <- read_csv("output/tables/español/event_study_resumen.csv", show_col_types = FALSE)

event_dict <- c(
  "IPI extremo" = "Top 10 IPI Shocks",
  "negatividad extrema" = "Top 10 Negativity Shocks"
)

serie_dict <- c(
  "TRM" = "TRM (USD/COP)",
  "COLCAP" = "MSCI COLCAP",
  "Precio energía XM" = "XM Spot Energy Price",
  "TES 10Y" = "TES 10Y Yield",
  "Pendiente TES 10Y-1Y" = "TES 10Y-1Y Yield Slope"
)

es_en <- es_raw %>%
  filter(!is.na(movimiento_medio)) %>%
  mutate(
    evento_en = recode(evento, !!!event_dict),
    serie_en = recode(serie, !!!serie_dict)
  )

p_es <- es_en %>%
  ggplot(aes(x = factor(horizonte), y = serie_en, fill = movimiento_medio)) +
  geom_tile(color = "white", linewidth = 0.4) +
  facet_wrap(~evento_en) +
  scale_fill_gradient2(low = "#8f5d2c", mid = "#f5f1e6", high = "#2f6f73", midpoint = 0, na.value = "#eeeeee") +
  labs(
    title = "Heatmap of Cumulative Post-Event Market Responses",
    subtitle = "Mean cumulative movement across calendar horizons following extreme presidential communicative shocks",
    x = "Post-Event Horizon (Calendar Days)", y = NULL, fill = "Mean Cumulative Movement"
  ) +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold", size = 11), legend.position = "bottom")

ggsave(file.path(out_en, "event_study_respuestas_heatmap.png"), p_es, width = 9.5, height = 5.5, dpi = 300)
ggsave(file.path(paper_en, "event_study_respuestas_heatmap.png"), p_es, width = 9.5, height = 5.5, dpi = 300)
cat("  -> Figure 9 saved.\n")

# ------------------------------------------------------------------------------
# 10. Figure 7: DCC-GARCH Dynamic Conditional Correlations Panel
# ------------------------------------------------------------------------------
cat("\n[10/10] Generating Figure 7: DCC-GARCH Dynamic Conditional Correlations Panel...\n")

# Build financial panel for DCC estimation
observed_dates <- market_master %>%
  filter(trm_observed, colcap_observed, tes_10y_observed, tes_slope_10y_1y_observed) %>%
  pull(date) %>% unique() %>% sort()

observed_market <- market_master %>%
  filter(date %in% observed_dates) %>%
  arrange(date) %>%
  mutate(
    ret_trm = log(trm) - lag(log(trm)),
    ret_colcap = log(colcap) - lag(log(colcap)),
    diff_tes_10y = tes_10y - lag(tes_10y),
    diff_tes_slope = tes_slope_10y_1y - lag(tes_slope_10y_1y)
  ) %>%
  select(date, ret_trm, ret_colcap, diff_tes_10y, diff_tes_slope)

# Next observed date helper
next_obs <- function(dates, valid_dates) {
  sapply(dates, function(d) {
    fut <- valid_dates[valid_dates > d]
    if (length(fut) == 0) as.Date(NA) else min(fut)
  })
}

# Discourse window aggregation
discourse_window <- ipi_daily %>%
  mutate(next_trading_date = as.Date(next_obs(date, observed_dates))) %>%
  filter(!is.na(next_trading_date)) %>%
  group_by(next_trading_date) %>%
  summarise(
    date_sentiment = max(date),
    polaridad = sum(polaridad, na.rm = TRUE),
    ipi_tweets_n = sum(tweets_n, na.rm = TRUE),
    ipi_polaridad = sum(polaridad, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    sentimiento_promedio_intervalo = if_else(ipi_tweets_n > 0, ipi_polaridad / ipi_tweets_n, NA_real_),
    volumen_log_intervalo = log1p(ipi_tweets_n),
    sentimiento_estandarizado = as.numeric(scale(sentimiento_promedio_intervalo)),
    volumen_estandarizado = as.numeric(scale(volumen_log_intervalo)),
    ipi = sentimiento_estandarizado * volumen_estandarizado
  ) %>%
  rename(date = next_trading_date)

panel_bursatil <- discourse_window %>%
  left_join(observed_market, by = "date") %>%
  arrange(date)

df_dcc7 <- panel_bursatil %>%
  select(ipi, polaridad, ret_trm, ret_colcap, diff_tes_10y, diff_tes_slope) %>%
  drop_na()

cat("  Fitting DCC-GARCH model on", nrow(df_dcc7), "complete observations...\n")
dcc_vars <- colnames(df_dcc7)
uspec_list <- lapply(dcc_vars, function(nm) {
  ugarchspec(
    variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
    mean.model = list(armaOrder = c(1, 0)),
    distribution.model = "std"
  )
})
mspec7 <- multispec(uspec_list)
dcc_spec7 <- dccspec(uspec = mspec7, dccOrder = c(1, 1), distribution = "mvt")
dcc_fit7 <- dccfit(dcc_spec7, data = df_dcc7, solver = "solnp")

rcor7 <- rcor(dcc_fit7)
fechas_dcc <- panel_bursatil$date_sentiment[complete.cases(panel_bursatil %>% select(ipi, polaridad, ret_trm, ret_colcap, diff_tes_10y, diff_tes_slope))]

dcc_dict <- c(
  "rho_ipi_colcap" = "IPI vs COLCAP Return",
  "rho_ipi_tes" = "IPI vs TES 10Y Yield Change",
  "rho_ipi_trm" = "IPI vs TRM Return",
  "rho_pol_trm" = "Polarity vs TRM Return"
)

df_rho_plot_en <- tibble(
  date = fechas_dcc,
  rho_ipi_trm = rcor7[1, 3, ],
  rho_ipi_colcap = rcor7[1, 4, ],
  rho_ipi_tes = rcor7[1, 5, ],
  rho_pol_trm = rcor7[2, 3, ]
) %>%
  pivot_longer(-date, names_to = "par", values_to = "rho") %>%
  mutate(par_en = recode(par, !!!dcc_dict))

p_dcc <- df_rho_plot_en %>%
  ggplot(aes(x = date, y = rho, color = par_en)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = 0.65, show.legend = FALSE) +
  facet_wrap(~par_en, scales = "free_y", ncol = 2) +
  labs(
    title = "DCC-GARCH Dynamic Conditional Correlations",
    subtitle = "Estimated dynamic conditional correlations between presidential signals and Colombian asset returns",
    x = NULL, y = expression(rho[ij,t])
  ) +
  theme_minimal(base_size = 11) +
  theme(strip.text = element_text(face = "bold", size = 11))

ggsave(file.path(out_en, "econometria/dcc_correlaciones_dinamicas_panel.png"), p_dcc, width = 10, height = 6, dpi = 300)
ggsave(file.path(out_en, "dcc_correlaciones_dinamicas_panel.png"), p_dcc, width = 10, height = 6, dpi = 300)
ggsave(file.path(paper_en, "econometria/dcc_correlaciones_dinamicas_panel.png"), p_dcc, width = 10, height = 6, dpi = 300)
ggsave(file.path(paper_en, "dcc_correlaciones_dinamicas_panel.png"), p_dcc, width = 10, height = 6, dpi = 300)
cat("  -> Figure 7 saved.\n")

cat("\n===================================================================\n")
cat("All 10 English Publication Figures generated and saved successfully!\n")
cat("===================================================================\n")
