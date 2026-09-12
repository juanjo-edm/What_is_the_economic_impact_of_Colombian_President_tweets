# X (Twitter) User Timeline and Archive Collection Script
# Configurable workflow for one target account.
#
# Authors: Miguelangel Palma | Juan Jose Echeverry | Luis Eduardo Sandoval

# 1. Environment Configuration and Dependency Management ----------

library(httr2)
library(dplyr)
library(arrow)

# 2. User Configuration ----------

config <- list(
  target_user = "petrogustavo",

  run_history = FALSE,
  run_archive = TRUE,

  history_start_year = 2022,
  history_start_month = 8,
  history_end_year = 2025,
  history_end_month = 4,

  archive_start_time = "2022-08-07T00:00:00Z",
  archive_end_time = "2026-06-15T15:59:31Z",

  include_retweets = FALSE,
  include_replies = TRUE,
  include_quotes = TRUE,
  include_links = TRUE,
  lang = NULL,

  tweet_fields = c(
    "id",
    "text",
    "author_id",
    "created_at",
    "lang",
    "conversation_id",
    "possibly_sensitive"
  ),

  history_budget = 37.50,
  archive_budget = 40.14,
  cost_per_tweet = 0.05,
  tweets_per_window = 20,

  output_dir = file.path(
    "data",
    "raw",
    "twitter",
    "Tweets de Gustavo Petro",
    "twitter_archive"
  ),
  save_every_page = TRUE,
  export_final_csv = TRUE,
  export_final_parquet = FALSE,
  checkpoint = TRUE,
  verbose = TRUE,

  exclude_tweet_ids_file = file.path(
    "data",
    "raw",
    "twitter",
    "Tweets de Gustavo Petro",
    "petrogustavo_full.csv"
  ),
  exclude_tweet_ids_column = "id",
  exclude_tweet_ids = c()
)

if (!file.exists(config$exclude_tweet_ids_file)) {
  stop(
    "Existing tweet ID file not found: ",
    config$exclude_tweet_ids_file,
    call. = FALSE
  )
}

existing_tweets <- utils::read.csv(
  config$exclude_tweet_ids_file,
  colClasses = "character",
  check.names = FALSE
)

if (!config$exclude_tweet_ids_column %in% names(existing_tweets)) {
  stop(
    "Column '",
    config$exclude_tweet_ids_column,
    "' not found in ",
    config$exclude_tweet_ids_file,
    call. = FALSE
  )
}

existing_tweet_ids <- existing_tweets[[config$exclude_tweet_ids_column]]
existing_tweet_ids <- existing_tweet_ids[!is.na(existing_tweet_ids) & nzchar(existing_tweet_ids)]
config$exclude_tweet_ids <- unique(c(config$exclude_tweet_ids, existing_tweet_ids))

# 3. Security and Source Layer ----------

source(
  here::here(
    "scripts",
    "api_data_extraction",
    "Autentificacion",
    "Config.R"
  )
)

source(
  here::here(
    "scripts",
    "api_data_extraction",
    "Functions",
    "ScrapingFunctions.R"
  )
)

source(
  here::here(
    "scripts",
    "api_data_extraction",
    "Functions",
    "ScrapingFunctionsOnePerson.R"
  )
)

# 4. Historical Sampling Layer ----------

history_result <- NULL

if (isTRUE(config$run_history)) {
  history_result <- fetch_user_history(
    username = config$target_user,
    start_year = config$history_start_year,
    start_month = config$history_start_month,
    end_year = config$history_end_year,
    end_month = config$history_end_month,
    budget_usd = config$history_budget,
    cost_per_tweet = config$cost_per_tweet,
    tweets_per_window = config$tweets_per_window,
    output_dir = config$output_dir,
    include_retweets = config$include_retweets,
    include_replies = config$include_replies,
    include_quotes = config$include_quotes,
    include_links = config$include_links,
    lang = config$lang,
    tweet_fields = config$tweet_fields,
    exclude_tweet_ids = config$exclude_tweet_ids,
    export_final_csv = config$export_final_csv,
    export_final_parquet = config$export_final_parquet,
    checkpoint = config$checkpoint,
    verbose = config$verbose
  )

  print(history_result)
}

# 5. Full Archive Collection Layer ----------

archive_result <- NULL

if (isTRUE(config$run_archive)) {
  archive_result <- fetch_user_archive(
    username = config$target_user,
    start_time = config$archive_start_time,
    end_time = config$archive_end_time,
    budget_usd = config$archive_budget,
    cost_per_tweet = config$cost_per_tweet,
    output_dir = config$output_dir,
    include_retweets = config$include_retweets,
    include_replies = config$include_replies,
    include_quotes = config$include_quotes,
    include_links = config$include_links,
    lang = config$lang,
    tweet_fields = config$tweet_fields,
    exclude_tweet_ids = config$exclude_tweet_ids,
    export_final_csv = config$export_final_csv,
    export_final_parquet = config$export_final_parquet,
    save_every_page = config$save_every_page,
    checkpoint = config$checkpoint,
    verbose = config$verbose
  )

  print(archive_result)
}

# 6. Execution Summary ----------

list(
  history_result = history_result,
  archive_result = archive_result,
  config = config
)
