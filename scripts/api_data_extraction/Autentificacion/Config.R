# ---------------------------------------------------------
# 2. AUTHENTICATION
# ---------------------------------------------------------

# Store your bearer token in .Renviron or in the shell environment.
# Never commit real API credentials to the repository.

bearer_token = Sys.getenv("TWITTER_BEARER")

if (!nzchar(bearer_token)) {
  stop(
    "TWITTER_BEARER is not configured. Copy .Renviron.example to .Renviron ",
    "or export TWITTER_BEARER before running scraping scripts.",
    call. = FALSE
  )
}




