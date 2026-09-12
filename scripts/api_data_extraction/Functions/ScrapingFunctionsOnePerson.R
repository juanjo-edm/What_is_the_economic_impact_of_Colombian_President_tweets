# =============================================================================
# USER TIMELINE SCRAPER
# =============================================================================
#
# Purpose:
#   Download historical tweets from a specific Twitter/X user while
#   controlling API costs and ensuring reliable long-term collection.
#
# Main Features:
#   - Historical tweet collection
#   - Cost-aware sampling strategy
#   - Monthly stratified coverage
#   - Incremental persistence
#   - Automatic checkpoint recovery
#   - CSV and Parquet exports
#
# Dependencies:
#   - httr2
#   - dplyr
#   - arrow
#   - jsonlite
#
# External Requirements:
#   - fetch_tweets()
#     Custom function responsible for interacting with the Twitter/X API.
#
# =============================================================================


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# NULL coalescing operator
#
# Returns the left-hand value if it is not NULL.
# Otherwise returns the fallback value.
#
# Example:
#   x <- NULL
#   x %||% 10   # returns 10
# -----------------------------------------------------------------------------

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}


# -----------------------------------------------------------------------------
# Convert list columns into JSON strings for CSV compatibility
#
# Purpose:
#   CSV files cannot reliably store nested structures such as lists.
#   This helper converts list columns into JSON-encoded character strings,
#   making the data safe for CSV export while preserving information.
#
# Parameters:
#   df : data.frame
#
# Returns:
#   A modified data frame where list columns are serialized as JSON strings.
# -----------------------------------------------------------------------------

flatten_for_csv <- function(df){

  list_cols <- vapply(
    df,
    is.list,
    logical(1)
  )

  if(any(list_cols)){

    df[list_cols] <- lapply(

      df[list_cols],

      function(col){

        vapply(

          col,

          function(x){

            jsonlite::toJSON(
              x,
              auto_unbox = TRUE,
              null = "null"
            )

          },

          character(1)

        )

      }

    )
  }

  df
}


# -----------------------------------------------------------------------------
# Build a Twitter/X search query for a specific user
#
# Purpose:
#   Creates a query string compatible with the Twitter API search endpoint.
#
# Parameters:
#   username          : Twitter/X username
#   include_retweets  : Include retweets if TRUE
#   include_replies   : Include replies if TRUE
#
# Returns:
#   A search query string.
#
# Example:
#   build_user_query("elonmusk")
#
# Output:
#   "from:elonmusk -is:retweet -is:reply"
# -----------------------------------------------------------------------------

build_user_query <- function(
    username,
    include_retweets = FALSE,
    include_replies = FALSE,
    include_quotes = FALSE,
    include_links = TRUE,
    lang = NULL
) {

  # Validate input arguments
  stopifnot(
    is.character(username),
    length(username) == 1,
    nzchar(username)
  )

  # Base query restricted to a specific account
  query <- paste0("from:", username)

  if (!is.null(lang) && nzchar(lang)) {
    query <- paste(query, paste0("lang:", lang))
  }

  # Exclude retweets unless explicitly requested
  if (!include_retweets)
    query <- paste(query, "-is:retweet")

  # Exclude replies unless explicitly requested
  if (!include_replies)
    query <- paste(query, "-is:reply")

  if (!include_quotes)
    query <- paste(query, "-is:quote")

  if (!include_links)
    query <- paste(query, "-has:links")

  query
}


filter_excluded_tweet_ids <- function(df, exclude_tweet_ids = character()) {

  if (length(exclude_tweet_ids) == 0 || NROW(df) == 0)
    return(df)

  if (!"id" %in% names(df)) {
    stop("Cannot exclude tweet IDs because column 'id' is missing.", call. = FALSE)
  }

  excluded_ids <- unique(as.character(exclude_tweet_ids))
  excluded_ids <- excluded_ids[!is.na(excluded_ids) & nzchar(excluded_ids)]

  if (length(excluded_ids) == 0)
    return(df)

  df[!as.character(df$id) %in% excluded_ids, , drop = FALSE]
}


# =============================================================================
# PERIOD SCRAPER
# =============================================================================

# -----------------------------------------------------------------------------
# Download a sample of tweets from a user within a specific time window
#
# Purpose:
#   Acts as a lightweight wrapper around fetch_tweets().
#   It retrieves a limited number of tweets from a defined period.
#
# Parameters:
#   username          : Twitter/X username
#   start_time        : ISO timestamp for period start
#   end_time          : ISO timestamp for period end
#   target_tweets     : Maximum tweets requested
#   cost_per_tweet    : Cost estimation used for budgeting
#   verbose           : Print progress messages
#
# Returns:
#   A data frame containing tweets retrieved during the period.
#   Returns an empty data frame if the request fails.
# -----------------------------------------------------------------------------

fetch_period_sample <- function(
    username,
    start_time,
    end_time,
    target_tweets = 25L,
    cost_per_tweet = 0.01,
    include_retweets = FALSE,
    include_replies = FALSE,
    include_quotes = FALSE,
    include_links = TRUE,
    lang = NULL,
    verbose = TRUE,
    ...
) {

  # Build user-specific search query
  query <- build_user_query(
    username = username,
    include_retweets = include_retweets,
    include_replies = include_replies,
    include_quotes = include_quotes,
    include_links = include_links,
    lang = lang
  )

  # Request tweets from the API
  res <- fetch_tweets(
    query = query,
    start_time = start_time,
    end_time = end_time,
    max_results = target_tweets,
    cost_per_tweet = cost_per_tweet,
    verbose = verbose,
    ...
  )

  # Return empty data frame if request failed
  if (!isTRUE(res$ok))
    return(data.frame())

  # Return empty data frame if no tweet payload exists
  if (is.null(res$tweets))
    return(data.frame())

  # Return retrieved tweets
  res$tweets
}

# =============================================================================
# MONTHLY STRATIFIED SAMPLE
# =============================================================================

# -----------------------------------------------------------------------------
# Retrieve a representative sample of tweets for a specific month
#
# Purpose:
#   Instead of downloading tweets from the entire month in a single request,
#   the month is divided into three equally sized time windows.
#
#   This approach improves temporal coverage by reducing the risk of collecting
#   tweets concentrated in only one part of the month.
#
# Sampling Strategy:
#   Window 1 -> Beginning of the month
#   Window 2 -> Middle of the month
#   Window 3 -> End of the month
#
# For each window:
#   - A fixed number of tweets is requested.
#   - Results are collected independently.
#   - Duplicate tweets are removed at the end.
#
# Parameters:
#   username           : Twitter/X username
#   year               : Target year
#   month              : Target month
#   tweets_per_window  : Maximum tweets requested per window
#   verbose            : Print progress messages
#
# Returns:
#   A data frame containing all tweets collected for the month.
#
# Example:
#   fetch_month_sample(
#     username = "elonmusk",
#     year = 2024,
#     month = 5
#   )
# -----------------------------------------------------------------------------

fetch_month_sample <- function(
    username,
    year,
    month,
    tweets_per_window = 25L,
    cost_per_tweet = 0.01,
    include_retweets = FALSE,
    include_replies = FALSE,
    include_quotes = FALSE,
    include_links = TRUE,
    lang = NULL,
    exclude_tweet_ids = character(),
    verbose = TRUE,
    ...
) {

  # ---------------------------------------------------------------------------
  # Build the first day of the requested month
  # Example:
  #   year = 2024
  #   month = 05
  #
  # Result:
  #   2024-05-01
  # ---------------------------------------------------------------------------

  month_start <- as.Date(
    sprintf("%04d-%02d-01", year, month)
  )

  # ---------------------------------------------------------------------------
  # Calculate the first day of the following month.
  #
  # Example:
  #   2024-05-01 -> 2024-06-01
  # ---------------------------------------------------------------------------

  next_month <- seq(
    month_start,
    by = "month",
    length.out = 2
  )[2]

  # ---------------------------------------------------------------------------
  # Determine the last day of the target month.
  #
  # Example:
  #   next_month = 2024-06-01
  #   month_end  = 2024-05-31
  # ---------------------------------------------------------------------------

  month_end <- next_month - 1

  # ---------------------------------------------------------------------------
  # Compute the total number of days in the month.
  #
  # Example:
  #   May 2024 -> 31 days
  # ---------------------------------------------------------------------------

  days_month <- as.integer(month_end - month_start + 1)

  # ---------------------------------------------------------------------------
  # Create boundaries for three approximately equal time segments.
  #
  # Timeline example:
  #
  #   Month Start
  #        |
  #        v
  #
  #   [ Window 1 ] [ Window 2 ] [ Window 3 ]
  #
  #        ^            ^            ^
  #      cut_1        cut_2        cut_3
  #
  # cut_4 marks the end boundary.
  # ---------------------------------------------------------------------------

  cut_1 <- month_start

  cut_2 <- month_start + floor(days_month / 3)

  cut_3 <- month_start + floor((2 * days_month) / 3)

  cut_4 <- month_end + 1

  # Store all boundary dates in a vector
  cuts <- c(cut_1, cut_2, cut_3, cut_4)

  # Container used to accumulate results from each window
  collected <- list()

  # ---------------------------------------------------------------------------
  # Iterate through the three time windows
  #
  # Window 1:
  #   cut_1 -> cut_2
  #
  # Window 2:
  #   cut_2 -> cut_3
  #
  # Window 3:
  #   cut_3 -> cut_4
  # ---------------------------------------------------------------------------

  for(i in seq_len(3)) {

    # -------------------------------------------------------------------------
    # Convert date boundaries into Twitter API ISO-8601 timestamps
    #
    # Example:
    #   2024-05-01
    #
    # becomes:
    #   2024-05-01T00:00:00Z
    # -------------------------------------------------------------------------

    start_time <- sprintf(
      "%sT00:00:00Z",
      cuts[i]
    )

    end_time <- sprintf(
      "%sT00:00:00Z",
      cuts[i + 1]
    )

    # -------------------------------------------------------------------------
    # Progress reporting
    # -------------------------------------------------------------------------

    if (verbose) {

      message(
        sprintf(
          "[%d-%02d] Window %d",
          year,
          month,
          i
        )
      )

    }

    # -------------------------------------------------------------------------
    # Request tweets for the current time window
    #
    # fetch_period_sample() performs the actual API call and returns
    # a subset of tweets for the specified date range.
    # -------------------------------------------------------------------------

    tmp <- fetch_period_sample(
      username = username,
      start_time = start_time,
      end_time = end_time,
      target_tweets = tweets_per_window,
      cost_per_tweet = cost_per_tweet,
      include_retweets = include_retweets,
      include_replies = include_replies,
      include_quotes = include_quotes,
      include_links = include_links,
      lang = lang,
      verbose = verbose,
      ...
    )

    tmp <- filter_excluded_tweet_ids(
      tmp,
      exclude_tweet_ids = exclude_tweet_ids
    )

    # -------------------------------------------------------------------------
    # Store results only if tweets were retrieved.
    # Empty responses are ignored.
    # -------------------------------------------------------------------------

    if (NROW(tmp) > 0)
      collected[[length(collected) + 1]] <- tmp
  }

  # ---------------------------------------------------------------------------
  # If no tweets were collected from any window,
  # return an empty data frame.
  # ---------------------------------------------------------------------------

  if (length(collected) == 0)
    return(data.frame())

  # ---------------------------------------------------------------------------
  # Merge results from all windows.
  #
  # Because adjacent windows can occasionally produce overlapping records,
  # duplicates are removed using the tweet ID as a unique key.
  # ---------------------------------------------------------------------------

  dplyr::bind_rows(collected) |>
    dplyr::distinct(
      id,
      .keep_all = TRUE
    )
}

# =============================================================================
# HISTORICAL SCRAPER
# =============================================================================

# -----------------------------------------------------------------------------
# Download historical tweets using a monthly stratified sampling strategy
#
# Purpose:
#   This is the main orchestration function responsible for collecting
#   historical tweets from a user across a configurable date range.
#
# Key Features:
#   - Month-by-month processing
#   - Cost control through budget limits
#   - Automatic checkpoint recovery
#   - Incremental monthly persistence
#   - CSV and Parquet exports
#   - Duplicate removal
#   - Resume after interruptions
#
# Workflow:
#
#   1. Validate environment configuration
#   2. Generate monthly timeline
#   3. Resume from checkpoint if available
#   4. Download data month-by-month
#   5. Save monthly CSV and Parquet files
#   6. Update checkpoint after each month
#   7. Merge all monthly files
#   8. Export final consolidated dataset
#   9. Remove checkpoint when completed
#
# Parameters:
#   username             : Twitter/X username
#   start_year           : First year to collect
#   start_month          : First month to collect
#   end_year             : Last year to collect
#   end_month            : Last month to collect
#   budget_usd           : Maximum allowed collection cost
#   cost_per_tweet       : Estimated cost per tweet
#   tweets_per_window    : Sample size per monthly window
#   output_dir           : Directory used for exports
#   export_final_csv     : Export final CSV file
#   export_final_parquet : Export final Parquet file
#   checkpoint           : Enable recovery checkpoints
#   verbose              : Print progress messages
#
# Returns:
#   A summary list containing:
#     - username
#     - total tweets collected
#     - total cost
#     - exported files
# -----------------------------------------------------------------------------

fetch_user_history <- function(
    username,
    start_year,
    start_month,
    end_year,
    end_month,
    budget_usd = 37.5,
    cost_per_tweet = 0.01,
    tweets_per_window = 20L,
    output_dir = "twitter_data",
    include_retweets = FALSE,
    include_replies = FALSE,
    include_quotes = FALSE,
    include_links = TRUE,
    lang = NULL,
    tweet_fields = c("id", "text", "author_id", "created_at", "lang",
                     "conversation_id", "possibly_sensitive"),
    exclude_tweet_ids = character(),
    export_final_csv = TRUE,
    export_final_parquet = TRUE,
    checkpoint = TRUE,
    verbose = TRUE,
    ...
) {

  # ---------------------------------------------------------------------------
  # Validate authentication credentials.
  #
  # The scraper requires a Twitter/X Bearer Token stored in the
  # TWITTER_BEARER environment variable.
  # ---------------------------------------------------------------------------

  if (!nzchar(Sys.getenv("TWITTER_BEARER"))) {
    stop("TWITTER_BEARER not configured.")
  }

  # ---------------------------------------------------------------------------
  # Create output directory if it does not already exist.
  # ---------------------------------------------------------------------------

  dir.create(
    output_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )

  # ---------------------------------------------------------------------------
  # Define file locations used during execution.
  # ---------------------------------------------------------------------------

  checkpoint_file <- file.path(
    output_dir,
    paste0(username, "_checkpoint.rds")
  )

  final_csv <- file.path(
    output_dir,
    paste0(username, "_history.csv")
  )

  final_parquet <- file.path(
    output_dir,
    paste0(username, "_history.parquet")
  )

  # ---------------------------------------------------------------------------
  # Generate a monthly sequence covering the requested date range.
  #
  # Example:
  #
  #   Jan 2020
  #   Feb 2020
  #   Mar 2020
  #   ...
  #   Dec 2024
  # ---------------------------------------------------------------------------

  months <- seq(
    as.Date(
      sprintf(
        "%04d-%02d-01",
        start_year,
        start_month
      )
    ),
    as.Date(
      sprintf(
        "%04d-%02d-01",
        end_year,
        end_month
      )
    ),
    by = "month"
  )

  # ---------------------------------------------------------------------------
  # Global counters used throughout execution.
  # ---------------------------------------------------------------------------

  total_cost <- 0
  total_tweets <- 0

  # Month index from which processing starts.
  start_idx <- 1

  # ---------------------------------------------------------------------------
  # Checkpoint Recovery
  #
  # If a previous run was interrupted, restore state and continue from
  # the next unfinished month.
  # ---------------------------------------------------------------------------

  if (
    checkpoint &&
    file.exists(checkpoint_file)
  ) {

    cp <- readRDS(checkpoint_file)

    start_idx <- cp$next_index %||% 1
    total_cost <- cp$total_cost %||% 0
    total_tweets <- cp$total_tweets %||% 0

    if (verbose) {

      message(
        sprintf(
          "Checkpoint detected. Resuming from month index %d.",
          start_idx
        )
      )

    }
  }

  # ---------------------------------------------------------------------------
  # Main Monthly Processing Loop
  #
  # Iterate over every month in the requested period.
  # ---------------------------------------------------------------------------

  for (i in seq(
    from = start_idx,
    to = length(months)
  )) {

    current_month <- months[i]

    # Extract year and month values from current date.

    year <- as.integer(
      format(current_month, "%Y")
    )

    month <- as.integer(
      format(current_month, "%m")
    )

    # -------------------------------------------------------------------------
    # Define monthly output files.
    # -------------------------------------------------------------------------

    month_parquet <- file.path(
      output_dir,
      sprintf(
        "%s_%04d_%02d.parquet",
        username,
        year,
        month
      )
    )

    month_csv <- file.path(
      output_dir,
      sprintf(
        "%s_%04d_%02d.csv",
        username,
        year,
        month
      )
    )

    # -------------------------------------------------------------------------
    # Skip months already processed.
    #
    # This avoids unnecessary API calls and reduces costs.
    # -------------------------------------------------------------------------

    if (
      file.exists(month_parquet) &&
      file.exists(month_csv)
    ) {

      if (verbose) {

        message(
          sprintf(
            "[%d-%02d] Already downloaded. Skipping.",
            year,
            month
          )
        )

      }

      next
    }

    # -------------------------------------------------------------------------
    # Start processing current month.
    # -------------------------------------------------------------------------

    if (verbose) {

      message(
        sprintf(
          "[%d-%02d] Downloading...",
          year,
          month
        )
      )

    }

    # -------------------------------------------------------------------------
    # Retrieve monthly sample.
    #
    # Errors are trapped to prevent a single failed month from terminating
    # the entire historical collection process.
    # -------------------------------------------------------------------------

    df <- tryCatch(

      fetch_month_sample(
        username = username,
        year = year,
        month = month,
        tweets_per_window = tweets_per_window,
        cost_per_tweet = cost_per_tweet,
        include_retweets = include_retweets,
        include_replies = include_replies,
        include_quotes = include_quotes,
        include_links = include_links,
        lang = lang,
        exclude_tweet_ids = exclude_tweet_ids,
        tweet_fields = tweet_fields,
        verbose = verbose,
        ...
      ),

      error = function(e) {

        warning(
          sprintf(
            "[%d-%02d] Error: %s",
            year,
            month,
            conditionMessage(e)
          )
        )

        NULL
      }
    )

    # -------------------------------------------------------------------------
    # Handle empty responses.
    # -------------------------------------------------------------------------

    if (
      is.null(df) ||
      NROW(df) == 0
    ) {

      if (verbose) {

        message(
          sprintf(
            "[%d-%02d] No tweets returned.",
            year,
            month
          )
        )

      }

      next
    }

    # -------------------------------------------------------------------------
    # Estimate collection cost for this month.
    # -------------------------------------------------------------------------

    month_cost <- NROW(df) * cost_per_tweet

    # -------------------------------------------------------------------------
    # Budget Control
    #
    # Stop execution before exceeding the maximum allowed budget.
    # -------------------------------------------------------------------------

    if (
      (total_cost + month_cost) >
      budget_usd
    ) {

      warning(
        sprintf(
          "Budget reached. Current cost: %.2f USD",
          total_cost
        )
      )

      break
    }

    # -------------------------------------------------------------------------
    # Remove duplicate tweets.
    #
    # Tweet ID is treated as the primary unique identifier.
    # -------------------------------------------------------------------------

    df <- dplyr::distinct(
      df,
      id,
      .keep_all = TRUE
    )

    df <- filter_excluded_tweet_ids(
      df,
      exclude_tweet_ids = exclude_tweet_ids
    )

    if (NROW(df) == 0) {

      if (verbose) {
        message(
          sprintf(
            "[%d-%02d] No tweets remained after ID exclusion.",
            year,
            month
          )
        )
      }

      next
    }

    # =======================================================================
    # SAVE MONTHLY PARQUET
    # =======================================================================
    #
    # Parquet preserves original data types and nested structures.
    # Recommended format for analytics and long-term storage.
    # =======================================================================

    arrow::write_parquet(
      df,
      month_parquet
    )

    # =======================================================================
    # SAVE MONTHLY CSV
    # =======================================================================
    #
    # CSV cannot store nested structures.
    # List columns must first be serialized into JSON strings.
    # =======================================================================

    csv_df <- df

    list_cols <- names(
      Filter(
        is.list,
        csv_df
      )
    )

    if (length(list_cols) > 0) {

      for (col in list_cols) {

        csv_df[[col]] <- vapply(

          csv_df[[col]],

          function(x) {

            if (is.null(x))
              return(NA_character_)

            jsonlite::toJSON(
              x,
              auto_unbox = TRUE
            )

          },

          character(1)
        )
      }
    }

    utils::write.csv(
      csv_df,
      month_csv,
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )

    # -------------------------------------------------------------------------
    # Update cumulative statistics.
    # -------------------------------------------------------------------------

    total_cost <- total_cost + month_cost
    total_tweets <- total_tweets + NROW(df)

    # -------------------------------------------------------------------------
    # Progress summary.
    # -------------------------------------------------------------------------

    if (verbose) {

      message(
        sprintf(
          "[%d-%02d] Saved %d tweets | Total=%d | Cost=%.2f USD",
          year,
          month,
          NROW(df),
          total_tweets,
          total_cost
        )
      )

    }

    # -------------------------------------------------------------------------
    # Save checkpoint after every successful month.
    #
    # This allows the process to resume exactly where it stopped.
    # -------------------------------------------------------------------------

    if (checkpoint) {

      saveRDS(
        list(
          next_index = i + 1,
          total_cost = total_cost,
          total_tweets = total_tweets,
          updated_at = Sys.time()
        ),
        checkpoint_file
      )
    }
  }

  # ===========================================================================
  # FINAL CONSOLIDATION PHASE
  # ===========================================================================
  #
  # Combine all monthly Parquet files into a single dataset.
  # ===========================================================================

  parquet_files <- list.files(
    output_dir,
    pattern = paste0(
      "^",
      username,
      "_\\d{4}_\\d{2}\\.parquet$"
    ),
    full.names = TRUE
  )

  # If no files exist, return an empty summary.

  if (length(parquet_files) == 0) {

    return(
      list(
        username = username,
        tweets = 0,
        cost_usd = total_cost,
        csv_file = NULL,
        parquet_file = NULL
      )
    )
  }

  # Load all monthly datasets.

  final_df <- dplyr::bind_rows(
    lapply(
      parquet_files,
      arrow::read_parquet
    )
  )

  # Final duplicate removal.

  final_df <- dplyr::distinct(
    final_df,
    id,
    .keep_all = TRUE
  )

  final_df <- filter_excluded_tweet_ids(
    final_df,
    exclude_tweet_ids = exclude_tweet_ids
  )

  # ---------------------------------------------------------------------------
  # Export consolidated Parquet dataset.
  # ---------------------------------------------------------------------------

  if (export_final_parquet) {

    arrow::write_parquet(
      final_df,
      final_parquet
    )
  }

  # ---------------------------------------------------------------------------
  # Export consolidated CSV dataset.
  # ---------------------------------------------------------------------------

  if (export_final_csv) {

    csv_df <- flatten_for_csv(final_df)

    utils::write.csv(
      csv_df,
      final_csv,
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
  }

  # ---------------------------------------------------------------------------
  # Cleanup checkpoint.
  #
  # Once processing completes successfully the checkpoint is no longer needed.
  # ---------------------------------------------------------------------------

  if (
    checkpoint &&
    file.exists(checkpoint_file)
  ) {
    file.remove(checkpoint_file)
  }

  # ---------------------------------------------------------------------------
  # Return execution summary.
  # ---------------------------------------------------------------------------

  list(
    username = username,
    tweets = NROW(final_df),
    cost_usd = round(total_cost, 2),
    monthly_files = length(parquet_files),
    csv_file = if (file.exists(final_csv)) final_csv else NULL,
    parquet_file = if (file.exists(final_parquet)) final_parquet else NULL
  )
}

# =============================================================================
# FULL USER ARCHIVE
# =============================================================================
#
# Purpose:
#   Download every available tweet from a user within a specified
#   date range using full pagination.
#
# Unlike the monthly sampling approach, this function attempts to
# retrieve the complete archive available through the API.
#
# Key Features:
#   - Full pagination support
#   - Budget-aware collection
#   - Automatic checkpoint recovery
#   - Incremental page-level persistence
#   - CSV and Parquet exports
#   - Duplicate removal
#   - Resume after interruptions
#
# Requirements:
#   - fetch_tweets()
#   - build_user_query()
#
# =============================================================================


# -----------------------------------------------------------------------------
# Convert nested/list columns into JSON strings for CSV compatibility
#
# Purpose:
#   CSV files do not support nested objects.
#   This helper serializes list columns into JSON strings while
#   preserving the original information.
#
# Parameters:
#   df : data.frame
#
# Returns:
#   A CSV-safe version of the data frame.
# -----------------------------------------------------------------------------

flatten_for_csv <- function(df){

  # Return immediately if the data frame is empty
  if(NROW(df) == 0)
    return(df)

  # Identify list-type columns
  list_cols <- vapply(
    df,
    is.list,
    logical(1)
  )

  # Convert each list column into JSON strings
  if(any(list_cols)){

    df[list_cols] <- lapply(

      df[list_cols],

      function(col){

        vapply(

          col,

          function(x){

            jsonlite::toJSON(
              x,
              auto_unbox = TRUE,
              null = "null"
            )

          },

          character(1)

        )

      }

    )
  }

  df
}


# =============================================================================
# FULL ARCHIVE SCRAPER
# =============================================================================

# -----------------------------------------------------------------------------
# Download all available tweets from a user within a date range
#
# Purpose:
#   Retrieve every page of results returned by the Twitter/X API
#   until pagination is exhausted, the budget is reached,
#   or an error occurs.
#
# Collection Strategy:
#
#   Request Page 1
#          |
#          v
#   Save results
#          |
#          v
#   Read next_token
#          |
#          v
#   Request next page
#          |
#          v
#   Repeat until no next_token exists
#
# Parameters:
#   username          : Twitter/X username
#   start_time        : Start timestamp (ISO 8601)
#   end_time          : End timestamp (ISO 8601)
#   budget_usd        : Maximum spending limit
#   cost_per_tweet    : Estimated tweet cost
#   output_dir        : Export directory
#   save_every_page   : Persist every page separately
#   checkpoint        : Enable automatic recovery
#   verbose           : Print progress information
#
# Returns:
#   A summary list containing:
#     - username
#     - tweet count
#     - pages downloaded
#     - total cost
#     - exported files
# -----------------------------------------------------------------------------

fetch_user_archive <- function(

  username,

  start_time,
  end_time,

  budget_usd = 37.69,

  cost_per_tweet = 0.01,

  output_dir = "twitter_data",

  include_retweets = FALSE,

  include_replies = FALSE,

  include_quotes = FALSE,

  include_links = TRUE,

  lang = NULL,

  tweet_fields = c("id", "text", "author_id", "created_at", "lang",
                   "conversation_id", "possibly_sensitive"),

  exclude_tweet_ids = character(),

  export_final_csv = TRUE,

  export_final_parquet = TRUE,

  save_every_page = TRUE,

  checkpoint = TRUE,

  verbose = TRUE,

  ...

){

  # ---------------------------------------------------------------------------
  # Create export directory if it does not already exist.
  # ---------------------------------------------------------------------------

  dir.create(
    output_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )

  # ---------------------------------------------------------------------------
  # Define output files.
  # ---------------------------------------------------------------------------

  csv_file <- file.path(
    output_dir,
    paste0(username, "_archive.csv")
  )

  parquet_file <- file.path(
    output_dir,
    paste0(username, "_archive.parquet")
  )

  checkpoint_file <- file.path(
    output_dir,
    paste0(username, "_archive_checkpoint.rds")
  )

  # ---------------------------------------------------------------------------
  # Build query restricted to tweets created by the target account.
  #
  # Retweets and replies are excluded by default.
  # ---------------------------------------------------------------------------

  query <- build_user_query(
    username = username,
    include_retweets = include_retweets,
    include_replies = include_replies,
    include_quotes = include_quotes,
    include_links = include_links,
    lang = lang
  )

  # ---------------------------------------------------------------------------
  # Pagination state variables.
  #
  # next_token:
  #   Token returned by Twitter/X that points to the next page.
  # ---------------------------------------------------------------------------

  next_token <- NULL

  # Global execution counters

  total_cost <- 0
  total_tweets <- 0
  pages <- 0

  # Storage container for all downloaded pages

  collected <- list()

  # ===========================================================================
  # CHECKPOINT RECOVERY
  # ===========================================================================
  #
  # Restore previous execution state if a checkpoint exists.
  # ===========================================================================

  if(
    checkpoint &&
    file.exists(checkpoint_file)
  ){

    cp <- readRDS(checkpoint_file)

    next_token <- cp$next_token
    total_cost <- cp$total_cost
    total_tweets <- cp$total_tweets
    pages <- cp$pages

    if(verbose)

      message(
        sprintf(
          "Checkpoint loaded. Pages=%d Tweets=%d Cost=%.2f",
          pages,
          total_tweets,
          total_cost
        )
      )
  }

  # ===========================================================================
  # PAGINATION LOOP
  # ===========================================================================
  #
  # Continue requesting pages until:
  #
  #   - Budget is exhausted
  #   - No next_token exists
  #   - API returns an error
  #   - No tweets remain
  # ===========================================================================

  repeat{

    # -------------------------------------------------------------------------
    # Budget protection.
    # -------------------------------------------------------------------------

    if(total_cost >= budget_usd){

      warning(
        sprintf(
          "Budget limit reached: %.2f USD",
          total_cost
        )
      )

      break
    }

    # -------------------------------------------------------------------------
    # Request a page of tweets.
    #
    # next_token determines which page is retrieved.
    # -------------------------------------------------------------------------

    res <- tryCatch(

      fetch_tweets(

        query = query,

        start_time = start_time,
        end_time = end_time,

        next_token = next_token,

        max_results = 100,

        tweet_fields = tweet_fields,

        cost_per_tweet = cost_per_tweet,

        verbose = verbose,

        ...

      ),

      error = function(e){

        warning(
          sprintf(
            "Request failed: %s",
            conditionMessage(e)
          )
        )

        NULL
      }

    )

    # Stop if request failed

    if(is.null(res))
      break

    # -------------------------------------------------------------------------
    # Validate API response.
    # -------------------------------------------------------------------------

    if(!isTRUE(res$ok)){

      warning(
        sprintf(
          "API Error: %s",
          res$error_message %||% "unknown"
        )
      )

      break
    }

    # -------------------------------------------------------------------------
    # Stop when no tweets remain.
    # -------------------------------------------------------------------------

    if(
      is.null(res$tweets) ||
      NROW(res$tweets) == 0
    ){

      if(verbose)
        message("No more tweets available.")

      break
    }

    # -------------------------------------------------------------------------
    # Successful page retrieval.
    # -------------------------------------------------------------------------

    pages <- pages + 1

    df <- dplyr::as_tibble(
      res$tweets
    )

    n_page_raw <- NROW(df)

    df <- filter_excluded_tweet_ids(
      df,
      exclude_tweet_ids = exclude_tweet_ids
    )

    # Store page in memory

    collected[[length(collected)+1]] <- df

    # -------------------------------------------------------------------------
    # Update counters.
    # -------------------------------------------------------------------------

    n_page <- NROW(df)

    total_tweets <- total_tweets + n_page

    page_cost <- n_page_raw * cost_per_tweet

    total_cost <- total_cost + page_cost

    # -------------------------------------------------------------------------
    # Display execution progress.
    # -------------------------------------------------------------------------

    if(verbose){

      message(
        sprintf(
          "Page=%d | PageTweets=%d | TotalTweets=%d | Cost=%.2f USD",
          pages,
          n_page,
          total_tweets,
          total_cost
        )
      )
    }

    # =========================================================================
    # SAVE PAGE IMMEDIATELY
    # =========================================================================
    #
    # Each page can optionally be saved as an independent CSV file.
    #
    # Benefits:
    #   - Reduced data loss risk
    #   - Easier debugging
    #   - Recovery after crashes
    # =========================================================================

    if(save_every_page){

      page_file <- file.path(

        output_dir,

        sprintf(
          "%s_page_%05d.csv",
          username,
          pages
        )

      )

      tmp_csv <- flatten_for_csv(df)

      utils::write.csv(
        tmp_csv,
        page_file,
        row.names = FALSE,
        fileEncoding = "UTF-8"
      )
    }

    # -------------------------------------------------------------------------
    # Obtain token for the next page.
    # -------------------------------------------------------------------------

    next_token <- res$next_token

    # -------------------------------------------------------------------------
    # Stop if pagination is exhausted.
    # -------------------------------------------------------------------------

    if(
      is.null(next_token) ||
      !nzchar(next_token)
    ){

      if(verbose)
        message("Pagination exhausted.")

      break
    }

    # =========================================================================
    # SAVE CHECKPOINT
    # =========================================================================
    #
    # Stores pagination state so execution can continue from the
    # exact same page after interruptions.
    # =========================================================================

    if(checkpoint){

      saveRDS(

        list(

          next_token = next_token,

          total_cost = total_cost,

          total_tweets = total_tweets,

          pages = pages,

          updated_at = Sys.time()

        ),

        checkpoint_file

      )
    }
  }

  # ===========================================================================
  # FINAL DATASET CONSTRUCTION
  # ===========================================================================

  final_df <- if(length(collected) > 0){

    dplyr::bind_rows(collected)

  } else {

    data.frame()

  }

  # ---------------------------------------------------------------------------
  # Remove duplicates using tweet ID.
  # ---------------------------------------------------------------------------

  if(
    NROW(final_df) > 0 &&
    "id" %in% names(final_df)
  ){

    final_df <- dplyr::distinct(
      final_df,
      id,
      .keep_all = TRUE
    )

    final_df <- filter_excluded_tweet_ids(
      final_df,
      exclude_tweet_ids = exclude_tweet_ids
    )
  }

  # ===========================================================================
  # EXPORT FINAL DATASET
  # ===========================================================================

  if(NROW(final_df) > 0){

    if (export_final_csv) {

      tmp_final <- flatten_for_csv(
        final_df
      )

      utils::write.csv(
        tmp_final,
        csv_file,
        row.names = FALSE,
        fileEncoding = "UTF-8"
      )
    }

    if (export_final_parquet) {

      arrow::write_parquet(
        final_df,
        parquet_file
      )
    }
  }

  # ---------------------------------------------------------------------------
  # Remove checkpoint after successful completion.
  # ---------------------------------------------------------------------------

  if(
    checkpoint &&
    file.exists(checkpoint_file)
  ){
    file.remove(checkpoint_file)
  }

  # ===========================================================================
  # EXECUTION SUMMARY
  # ===========================================================================
  #
  # Return metadata describing the completed archive download.
  # ===========================================================================

  list(

    username = username,

    tweets = NROW(final_df),

    pages = pages,

    cost_usd = round(
      total_cost,
      2
    ),

    csv_file = if(
      file.exists(csv_file)
    ) csv_file else NULL,

    parquet_file = if(
      file.exists(parquet_file)
    ) parquet_file else NULL

  )
}

