#' Execute requests against the X (Twitter) v2 API via advanced search
#'
#' Implements a robust interface for the Search All/Recent endpoint.
#' Retry logic is fully delegated to httr2's native req_retry(), replacing
#' the manual while loop. A token-bucket throttle (req_throttle) is applied
#' globally across all calls to prevent rate limiting when fetch_tweets() is
#' invoked repeatedly from fetch_all_day() and fetch_month_balanced().
#'
#' Retry behaviour:
#' - Network/transport failures → retry_on_failure = TRUE
#' - Rate limiting (HTTP 429) → is_transient + after (x-rate-limit-reset)
#' - Server errors (HTTP 5xx) → is_transient + backoff (full jitter)
#' - Client errors (HTTP 4xx) → non-retryable, returned immediately
#'
#' Throttle behaviour:
#' - capacity = 1, fill_time_s = 15 → max 1 request every 15 seconds.
#' - Applies globally across all calls within the same R session.
#' - For 31 days x 1 req/day: adds ~7.5 min total, prevents all 429s.
#'
#' @param query Character. Search parameters and API filters.
#' @param start_time Character. Start timestamp in ISO 8601 format (UTC).
#' @param end_time Character. End timestamp in ISO 8601 format (UTC).
#' @param next_token Character. Pagination cursor for the next result set.
#' @param bearer_token Character. X API Bearer Token credential.
#' @param endpoint Character. Target API resource URL.
#' @param max_results Integer. Records per page. Clamped to API range [10, 100].
#' @param tweet_fields Character vector. Metadata fields to include in response.
#' @param max_retries Integer. Maximum retry attempts for recoverable failures.
#' @param base_wait Numeric. Base wait time in seconds for the backoff algorithm.
#' @param verbose Logical. Whether to print retry and rate limit events.
#' @param cost_per_tweet Numeric. API cost in USD per tweet read (default: 0.005).
#'
#' @return List with fields: ok, status, tweets, next_token, meta, raw,
#' request_id, tweets_n, estimated_cost. On failure: ok, error_type,
#' error_message, and optionally status / raw / request_id.
fetch_tweets <- function(
    query,
    start_time,
    end_time,
    next_token = NULL,
    bearer_token = Sys.getenv("TWITTER_BEARER"),
    endpoint = "https://api.x.com/2/tweets/search/all",
    max_results = 100L,
    tweet_fields = c("id", "text", "author_id", "created_at", "lang",
                     "conversation_id", "possibly_sensitive"),
    max_retries = 6L,
    base_wait = 2,
    verbose = TRUE,
    cost_per_tweet = 0.005
) {
  
  # ---------------------------------------------------------------------------
  # BLOCK 1: INPUT VALIDATION AND SANITIZATION
  # ---------------------------------------------------------------------------
  
  if (!nzchar(bearer_token))
    return(list(
      ok = FALSE,
      error_type = "config",
      error_message = "TWITTER_BEARER credential not found or empty."
    ))
  
  if (!is.character(query) || length(query) != 1L || !nzchar(query))
    return(list(
      ok = FALSE,
      error_type = "input",
      error_message = "Invalid or null 'query' parameter."
    ))
  
  if (!is.character(start_time) || !is.character(end_time))
    return(list(
      ok = FALSE,
      error_type = "input",
      error_message = "Time parameters must be RFC3339-formatted strings."
    ))
  
  max_results <- max(10L, min(100L, as.integer(max_results)))
  tweet_fields_str <- paste(unique(tweet_fields), collapse = ",")
  
  # ---------------------------------------------------------------------------
  # BLOCK 2: REQUEST CONSTRUCTION AND EXECUTION
  # ---------------------------------------------------------------------------
  
  # Build the base request using native pipe and bearer token auth helper.
  # req_auth_bearer_token() automatically redacts the Authorization header
  # in all console output to prevent accidental credential leakage.
  req <- httr2::request(endpoint) |>
    httr2::req_auth_bearer_token(bearer_token) |>
    httr2::req_url_query(
      query = query,
      start_time = start_time,
      end_time = end_time,
      max_results = max_results,
      `tweet.fields` = tweet_fields_str
    ) |>
    # Throttle limits the request rate at the token-bucket level.
    # capacity = 1, fill_time_s = 15 → max 1 request every 15 seconds.
    # This applies globally across ALL calls to fetch_tweets(), including
    # calls from different days inside the fetch_month_balanced loop,
    # preventing the 429 rate limit errors caused by rapid successive requests.
    httr2::req_throttle(capacity = 1, fill_time_s = 15) |>
    # Disable httr2 automatic error conversion for manual status management.
    # This ensures req_retry() can inspect 429 / 5xx responses via is_transient
    # instead of having httr2 throw an error before the retry logic runs.
    httr2::req_error(is_error = \(resp) FALSE) |>
    # Delegate the entire retry cycle to httr2's native implementation.
    # This replaces the manual while loop, Sys.sleep calls, and attempt counter.
    #
    # retry_on_failure = TRUE → retries low-level transport failures
    # (DNS errors, connection resets, timeouts)
    #
    # is_transient → marks HTTP 429 and 5xx as retryable responses;
    # other 4xx are non-transient and never retried
    #
    # backoff → full-jitter exponential backoff for 5xx and
    # network failures; prevents thundering herd
    #
    # after → for HTTP 429 only: extracts the server-provided
    # reset timestamp from x-rate-limit-reset and
    # returns the exact seconds to wait;
    # returns NA for all other statuses, falling
    # back to backoff() instead
    httr2::req_retry(
      max_tries = max_retries,
      retry_on_failure = TRUE,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L:599L),
      
      backoff = \(attempt) {
        wait_s <- runif(1, min = base_wait, max = base_wait * (2^(attempt - 1L)))
        if (verbose) message(sprintf(
          "Transient error. Retrying (attempt %d/%d) in %.1fs.",
          attempt, max_retries, wait_s
        ))
        wait_s
      },
      
      after = \(resp) {
        if (httr2::resp_status(resp) != 429L) return(NA)
        reset <- suppressWarnings(
          as.numeric(httr2::resp_header(resp, "x-rate-limit-reset"))
        )
        wait_s <- if (!is.na(reset)) max(5, ceiling(reset - as.numeric(Sys.time()))) else NA
        if (verbose && !is.na(wait_s)) message(sprintf(
          "Rate limit exceeded (429). Waiting %ds.", ceiling(wait_s)
        ))
        wait_s
      }
    )
  
  # Append pagination cursor only when a valid token is available.
  # Done after the pipe chain to avoid interrupting the fluent interface.
  if (!is.null(next_token) && nzchar(next_token))
    req <- httr2::req_url_query(req, next_token = next_token)
  
  # Execute the fully configured request.
  # Two possible failure paths after this point:
  # A) Network failure surviving all retries → req_perform() throws
  # → tryCatch captures it as an error object
  # B) 429 / 5xx surviving all retries → response is returned normally
  # → handled in the status section below (req_error = FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) e)
  
  # Path A: terminal network failure after all retries exhausted
  if (inherits(resp, "error"))
    return(list(
      ok = FALSE,
      error_type = "retry_exhausted",
      error_message = sprintf(
        "All %d retry attempts exhausted: %s", max_retries, conditionMessage(resp)
      )
    ))
  
  # ---------------------------------------------------------------------------
  # BLOCK 3: RESPONSE PARSING AND STATUS HANDLING
  # ---------------------------------------------------------------------------
  
  status <- httr2::resp_status(resp)
  request_id <- httr2::resp_header(resp, "x-request-id")
  
  # SUCCESS (HTTP 2xx): parse JSON and compute request cost
  if (status >= 200L && status < 300L) {
    
    # check_type = FALSE: avoids failure if the API returns a valid 200 response
    # with a non-standard Content-Type header (edge case but has been observed)
    body <- tryCatch(
      httr2::resp_body_json(resp, check_type = FALSE, simplifyVector = TRUE),
      error = function(e) {
        if (verbose) message("JSON deserialization error: ", conditionMessage(e))
        NULL
      }
    )
    
    if (is.null(body))
      return(list(
        ok = FALSE,
        error_type = "parse",
        error_message = "JSON deserialization failed."
      ))
    
    tweets_n <- NROW(body$data)
    estimated_cost <- tweets_n * cost_per_tweet
    
    return(list(
      ok = TRUE,
      status = status,
      tweets = body$data,
      next_token = body$meta$next_token,
      meta = body$meta,
      raw = body,
      request_id = request_id,
      tweets_n = tweets_n,
      estimated_cost = estimated_cost
    ))
  }
  
  # Path B: non-2xx response after req_retry() gave up.
  # 429 / 5xx → retry threshold exhausted after max_retries attempts.
  # Other 4xx → non-transient, was never retried (is_transient = FALSE).
  list(
    ok = FALSE,
    status = status,
    error_type = if (status %in% c(429L, 500L:599L)) "retry_exhausted" else "http_client",
    error_message = if (status %in% c(429L, 500L:599L)) {
      sprintf("HTTP %d — retry threshold exhausted after %d attempts.", status, max_retries)
    } else {
      sprintf("HTTP %d — non-recoverable client error.", status)
    },
    raw = tryCatch(httr2::resp_body_string(resp), error = function(e) NULL),
    request_id = request_id
  )
}

#' Orchestrate daily tweet extraction with pagination and cost tracking
#'
#' Intermediate layer that collects tweets within a specific calendar day.
#' Implements recursive pagination with dynamic page size calculation to
#' minimize API costs. Uses next-day midnight as the exclusive end_time
#' boundary, ensuring full-day coverage with no gaps between consecutive days.
#'
#' @param query              Character. Search terms and API filters.
#' @param day                Date or Character. Target date in YYYY-MM-DD format.
#' @param target_sample_size Integer. Maximum records to collect for the day.
#' @param start_hour         Integer. Collection window start hour (0-23).
#' @param end_hour           Integer. Collection window end hour (0-23).
#' @param bearer_token       Character. X API Bearer Token credential.
#' @param endpoint           Character. API search resource URL.
#' @param tweet_fields       Character vector. Metadata fields to retrieve.
#' @param max_results        Integer. Maximum page size (API limit: 10-100).
#' @param max_pages          Integer. Safety cap against infinite pagination.
#' @param max_empty_pages    Integer. Consecutive empty response tolerance.
#' @param pause_between_pages Numeric. Delay in seconds between page requests.
#' @param cost_per_tweet     Numeric. API cost in USD per tweet read (default: 0.005).
#' @param verbose            Logical. Whether to report progress and cost to console.
#'
#' @return List with fields: ok, status, error_type, error_message, day,
#'   start_time, end_time, tweets (data.frame), n, pages, next_token,
#'   errors (list), estimated_cost (numeric, total USD cost for the day).
fetch_all_day <- function(
    query,
    day,
    target_sample_size   = 500L,
    start_hour           = 0L,
    end_hour             = 23L,
    bearer_token         = Sys.getenv("TWITTER_BEARER"),
    endpoint             = "https://api.x.com/2/tweets/search/all",
    tweet_fields         = c("id", "text", "author_id", "created_at", "lang",
                             "conversation_id", "possibly_sensitive"),
    max_results          = 100L,
    max_pages            = 100L,
    max_empty_pages      = 2L,
    pause_between_pages  = 0.25,
    cost_per_tweet       = 0.005,
    verbose              = TRUE
) {
  
  # ---------------------------------------------------------------------------
  # BLOCK 1: SANITIZATION AND VALIDATION (FAIL-FAST)
  # ---------------------------------------------------------------------------
  
  empty_result <- function(error_type, error_message) {
    list(
      ok = FALSE, status = NA_integer_, error_type = error_type,
      error_message = error_message, tweets = data.frame(),
      n = 0L, pages = 0L, next_token = NULL,
      errors = list(), estimated_cost = 0
    )
  }
  
  if (!nzchar(bearer_token))
    return(empty_result("config", "TWITTER_BEARER variable not initialized."))
  
  if (!is.character(query) || length(query) != 1L || !nzchar(query))
    return(empty_result("input", "Invalid or malformed 'query' parameter."))
  
  day_chr <- if (inherits(day, "Date")) format(day, "%Y-%m-%d") else as.character(day)
  
  if (!grepl("^\\d{4}-\\d{2}-\\d{2}$", day_chr))
    return(empty_result("input", "Date format must be 'YYYY-MM-DD'."))
  
  start_hour <- as.integer(start_hour)
  end_hour   <- as.integer(end_hour)
  
  if (is.na(start_hour) || is.na(end_hour) ||
      start_hour < 0L   || end_hour > 23L  || start_hour > end_hour)
    return(empty_result("input", "start_hour/end_hour range out of bounds (0-23)."))
  
  # Construct RFC3339 timestamps for the collection window.
  # start_time: beginning of the specified hour on the target day.
  # end_time: midnight of the NEXT day (exclusive boundary).
  # Using next-day midnight as end_time ensures complete day coverage
  # with no gaps or overlaps between consecutive daily queries.
  start_time <- sprintf("%sT%02d:00:00Z", day_chr, start_hour)
  end_time   <- sprintf(
    "%sT00:00:00Z",
    format(as.Date(day_chr) + 1L, "%Y-%m-%d")
  )
  
  # State accumulators
  all_pages   <- list()
  errors      <- list()
  next_token  <- NULL
  pages       <- 0L
  empty_pages <- 0L
  collected_n <- 0L
  total_cost  <- 0
  
  # ---------------------------------------------------------------------------
  # BLOCK 2: RECURSIVE PAGINATION LOOP
  # ---------------------------------------------------------------------------
  
  repeat {
    
    if (pages >= max_pages) {
      if (verbose) message(sprintf("[%s] Exit: max_pages=%d reached.", day_chr, max_pages))
      break
    }
    if (collected_n >= target_sample_size) {
      if (verbose) message(sprintf(
        "[%s] Daily target reached: %d tweets.", day_chr, target_sample_size
      ))
      break
    }
    
    # Dynamic page size: never request more tweets than the remaining quota.
    # This is the primary cost control mechanism — avoids paying for
    # tweets that would be discarded by the target cap.
    remaining <- target_sample_size - collected_n
    page_size <- max(10L, min(as.integer(max_results), remaining))
    
    res <- fetch_tweets(
      query          = query,
      start_time     = start_time,
      end_time       = end_time,
      next_token     = next_token,
      bearer_token   = bearer_token,
      endpoint       = endpoint,
      max_results    = page_size,
      tweet_fields   = tweet_fields,
      cost_per_tweet = cost_per_tweet,
      verbose        = verbose
    )
    
    pages <- pages + 1L
    
    # Accumulate cost for every request (0 tweets = $0.00)
    page_cost  <- res$estimated_cost %||% 0
    total_cost <- total_cost + page_cost
    
    # --- Error handling ---
    if (!isTRUE(res$ok)) {
      errors[[length(errors) + 1L]] <- list(
        page          = pages,
        status        = res$status        %||% NA_integer_,
        error_type    = res$error_type    %||% "unknown",
        error_message = res$error_message %||% "unknown",
        request_id    = res$request_id    %||% NA_character_,
        raw           = res$raw           %||% NULL
      )
      critical_types <- c("http_client", "config", "input", "retry_exhausted", "parse")
      if (!is.null(res$error_type) && res$error_type %in% critical_types) {
        if (verbose) message(sprintf(
          "[%s] Critical error on page %d (%s): %s",
          day_chr, pages, res$error_type, res$error_message
        ))
      }
      break
    }
    
    tweets     <- res$tweets
    next_token <- res$next_token
    
    # --- Empty page handling ---
    if (is.null(tweets) || NROW(tweets) == 0L) {
      empty_pages <- empty_pages + 1L
      if (verbose) message(sprintf(
        "[%s] Empty response on page %d (%d/%d consecutive).",
        day_chr, pages, empty_pages, max_empty_pages
      ))
      if (empty_pages >= max_empty_pages) break
      
    } else {
      empty_pages <- 0L
      all_pages[[length(all_pages) + 1L]] <- tweets
      collected_n <- collected_n + NROW(tweets)
      
      if (verbose) message(sprintf(
        "[%s] +%d tweets (Total: %d | Page cost: $%.4f | Day cost: $%.4f USD)",
        day_chr, NROW(tweets), collected_n, page_cost, total_cost
      ))
    }
    
    if (is.null(next_token) || !nzchar(next_token)) {
      if (verbose) message(sprintf("[%s] Cursor exhausted (no next_token).", day_chr))
      break
    }
    
    if (pause_between_pages > 0) Sys.sleep(pause_between_pages)
  }
  
  # ---------------------------------------------------------------------------
  # BLOCK 3: CONSOLIDATION AND POST-PROCESSING
  # ---------------------------------------------------------------------------
  
  out <- if (length(all_pages) > 0L) dplyr::bind_rows(all_pages) else data.frame()
  
  if (NROW(out) > 0L && "id" %in% names(out))
    out <- dplyr::distinct(out, id, .keep_all = TRUE)
  
  if (NROW(out) > target_sample_size)
    out <- dplyr::slice_head(out, n = target_sample_size)
  
  if (verbose) message(sprintf(
    "[%s] Completed: %d tweets | Estimated day cost: $%.4f USD",
    day_chr, NROW(out), total_cost
  ))
  
  list(
    ok             = TRUE,
    status         = 200L,
    error_type     = NULL,
    error_message  = NULL,
    day            = day_chr,
    start_time     = start_time,
    end_time       = end_time,
    tweets         = out,
    n              = NROW(out),
    pages          = pages,
    next_token     = next_token,
    errors         = errors,
    estimated_cost = total_cost
  )
}


#' Stratified monthly orchestration for X (Twitter) data collection
#'
#' High-level controller that distributes a monthly collection target evenly
#' across all days of the month using floor division with remainder allocation.
#' Includes two layers of budget protection:
#'   1. Pre-flight check: stops execution before any API call if the projected
#'      cost exceeds max_budget_usd.
#'   2. Mid-execution guard: halts the daily loop if accumulated cost reaches
#'      the budget cap, preserving all data collected up to that point.
#' Applies month-level deduplication after consolidation and produces a full
#' cost audit report upon completion.
#'
#' @param query          Character. Search parameters and API filters.
#' @param year           Integer. Target year.
#' @param month          Integer. Target month (1-12).
#' @param total_target   Integer. Total tweets to collect for the month (default: 396).
#' @param cost_per_tweet Numeric. API cost in USD per tweet read (default: 0.005).
#'   Passed down to fetch_all_day() and fetch_tweets() for unified accounting.
#' @param max_budget_usd Numeric. Hard spend cap in USD. Pre-flight check uses
#'   the theoretical maximum (total_target * cost_per_tweet). Mid-execution
#'   check uses the real accumulated cost. Default: 2.50.
#' @param verbose        Logical. Whether to print progress, cost events,
#'   and days returning zero tweets to the console (default: TRUE).
#' @param ...            Additional arguments forwarded to fetch_all_day()
#'   (bearer_token, endpoint, tweet_fields, max_results, etc.).
#'
#' @return List with fields:
#'   \item{total_requested}{Integer. Original monthly target.}
#'   \item{total_obtained}{Integer. Unique tweets collected after deduplication.}
#'   \item{data}{data.frame. Consolidated, deduplicated tweet dataset.}
#'   \item{cost_audit}{List. Full cost breakdown: projected cost, actual cost,
#'     budget utilization, days with data, days with errors, and period.}
fetch_month_balanced <- function(
    query,
    year,
    month,
    total_target   = 396L,
    cost_per_tweet = 0.005,
    max_budget_usd = 2.50,
    verbose        = TRUE,
    ...
) {
  
  # ---------------------------------------------------------------------------
  # BLOCK 1: PRE-FLIGHT BUDGET VALIDATION
  # ---------------------------------------------------------------------------
  
  # Calculate the theoretical maximum cost before touching the API.
  # This is a hard stop — no requests are made if the budget would be exceeded.
  projected_cost <- total_target * cost_per_tweet
  
  if (projected_cost > max_budget_usd) {
    stop(sprintf(
      paste(
        "Budget guard triggered: projected cost $%.4f USD exceeds limit of $%.4f USD.",
        "Reduce total_target (current: %d tweets) or increase max_budget_usd to proceed."
      ),
      projected_cost, max_budget_usd, total_target
    ))
  }
  
  if (verbose) message(sprintf(
    "Budget pre-check passed: projected max cost $%.4f USD | limit: $%.4f USD",
    projected_cost, max_budget_usd
  ))
  
  # ---------------------------------------------------------------------------
  # BLOCK 2: TEMPORAL BOUNDARY DETERMINATION
  # ---------------------------------------------------------------------------
  
  start_date <- as.Date(sprintf("%d-%02d-01", year, month))
  
  next_month <- if (month == 12L) {
    sprintf("%d-01-01", year + 1L)
  } else {
    sprintf("%d-%02d-01", year, month + 1L)
  }
  
  end_date <- as.Date(next_month) - 1L
  days_seq <- seq.Date(start_date, end_date, by = "day")
  n_days   <- length(days_seq)
  
  # ---------------------------------------------------------------------------
  # BLOCK 3: BALANCED DISTRIBUTION ALGORITHM
  # ---------------------------------------------------------------------------
  
  # Floor division provides the base daily quota.
  # The remainder is distributed one unit at a time across the first N days,
  # guaranteeing that sum(daily_quotas) == total_target exactly.
  base_per_day <- floor(total_target / n_days)
  remainder    <- total_target %% n_days
  daily_quotas <- rep(base_per_day, n_days)
  
  if (remainder > 0L)
    daily_quotas[seq_len(remainder)] <- daily_quotas[seq_len(remainder)] + 1L
  
  if (verbose) message(sprintf(
    "\n--- Monthly Plan: %d tweets | %d days | ~%d/day | Projected cost: $%.4f USD | Cap: $%.4f USD ---",
    total_target, n_days, base_per_day, projected_cost, max_budget_usd
  ))
  
  # ---------------------------------------------------------------------------
  # BLOCK 4: SEQUENTIAL DAILY EXTRACTION WITH REAL-TIME COST MONITORING
  # ---------------------------------------------------------------------------
  
  all_month_tweets <- list()
  total_cost_usd   <- 0
  days_with_data   <- 0L
  days_with_errors <- 0L
  budget_pct       <- 0   # Initialized before the loop to ensure cost_audit
  # is always defined, even if the loop exits early.
  
  for (i in seq_along(days_seq)) {
    
    current_day  <- days_seq[i]
    target_today <- daily_quotas[i]
    
    res <- fetch_all_day(
      query              = query,
      day                = current_day,
      target_sample_size = target_today,
      cost_per_tweet     = cost_per_tweet,
      verbose            = verbose,
      ...
    )
    
    # Accumulate real daily cost using the correct field name from fetch_all_day.
    # fetch_all_day returns 'estimated_cost', not 'day_cost_usd'.
    total_cost_usd <- total_cost_usd + (res$estimated_cost %||% 0)
    budget_pct     <- total_cost_usd / max_budget_usd
    
    # Real-time budget monitoring: warn when approaching 90% of the cap
    if (budget_pct >= 0.90) {
      warning(sprintf(
        "Cost alert: $%.4f USD spent (%.1f%% of $%.2f USD budget after %s).",
        total_cost_usd, budget_pct * 100, max_budget_usd,
        format(current_day, "%Y-%m-%d")
      ))
    }
    
    if (isTRUE(res$ok) && NROW(res$tweets) > 0L) {
      all_month_tweets[[length(all_month_tweets) + 1L]] <- res$tweets
      days_with_data <- days_with_data + 1L
      
      if (verbose) message(sprintf(
        "[%s] Day complete: %d tweets | Running cost: $%.4f / $%.4f USD (%.1f%%)",
        format(current_day, "%Y-%m-%d"),
        NROW(res$tweets),
        total_cost_usd,
        max_budget_usd,
        budget_pct * 100
      ))
      
    } else {
      days_with_errors <- days_with_errors + 1L
      
      # Distinguish between API failures and days with genuinely zero results.
      # Both are reported so the user can diagnose whether the issue is the
      # query, the API access level, or an actual transport/auth error.
      if (verbose) {
        if (!isTRUE(res$ok)) {
          message(sprintf(
            "[%s] Day failed: %s",
            format(current_day, "%Y-%m-%d"),
            res$error_message %||% "unknown error"
          ))
        } else {
          message(sprintf(
            "[%s] Day returned 0 tweets (query may be too restrictive for this date).",
            format(current_day, "%Y-%m-%d")
          ))
        }
      }
    }
    
    # Mid-execution budget guard: halts the loop if the cap is reached,
    # preserving all data collected up to this point.
    if (total_cost_usd >= max_budget_usd) {
      warning(sprintf(
        "Budget cap of $%.4f USD reached after day %s. Collection halted. Data preserved.",
        max_budget_usd, format(current_day, "%Y-%m-%d")
      ))
      break
    }
  }
  
  # ---------------------------------------------------------------------------
  # BLOCK 5: CONSOLIDATION AND MONTH-LEVEL DEDUPLICATION
  # ---------------------------------------------------------------------------
  
  final_df <- if (length(all_month_tweets) > 0L) {
    dplyr::bind_rows(all_month_tweets)
  } else {
    data.frame()
  }
  
  # Month-level deduplication: removes any tweet that appears in more than
  # one daily window (e.g., near a midnight boundary).
  if (NROW(final_df) > 0L && "id" %in% names(final_df)) {
    before_dedup  <- NROW(final_df)
    final_df      <- dplyr::distinct(final_df, id, .keep_all = TRUE)
    dupes_removed <- before_dedup - NROW(final_df)
    
    if (verbose && dupes_removed > 0L) message(sprintf(
      "Month-level deduplication: %d duplicate(s) removed.", dupes_removed
    ))
  }
  
  # ---------------------------------------------------------------------------
  # BLOCK 6: COST AUDIT REPORT
  # ---------------------------------------------------------------------------
  
  cost_audit <- list(
    period             = sprintf("%d-%02d", year, month),
    tweets_requested   = total_target,
    tweets_obtained    = NROW(final_df),
    cost_per_tweet_usd = cost_per_tweet,
    projected_cost_usd = projected_cost,
    actual_cost_usd    = total_cost_usd,
    max_budget_usd     = max_budget_usd,
    budget_utilization = round(budget_pct * 100, 2),
    days_total         = n_days,
    days_with_data     = days_with_data,
    days_with_errors   = days_with_errors
  )
  
  if (verbose) message(sprintf(
    paste(
      "\n========== MONTHLY COST AUDIT: %s ==========",
      " Tweets requested   : %d",
      " Tweets obtained    : %d",
      " Cost per tweet     : $%.4f USD",
      " Projected max cost : $%.4f USD",
      " Actual cost        : $%.4f USD",
      " Budget utilization : %.2f%% of $%.2f USD",
      " Days with data     : %d / %d",
      " Days with errors   : %d / %d",
      "=============================================",
      sep = "\n"
    ),
    cost_audit$period,
    cost_audit$tweets_requested,
    cost_audit$tweets_obtained,
    cost_audit$cost_per_tweet_usd,
    cost_audit$projected_cost_usd,
    cost_audit$actual_cost_usd,
    cost_audit$budget_utilization, max_budget_usd,
    cost_audit$days_with_data,   n_days,
    cost_audit$days_with_errors, n_days
  ))
  
  return(list(
    total_requested = total_target,
    total_obtained  = NROW(final_df),
    data            = final_df,
    cost_audit      = cost_audit
  ))
}
