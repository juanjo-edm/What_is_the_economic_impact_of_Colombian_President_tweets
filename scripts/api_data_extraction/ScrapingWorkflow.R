# X (Twitter) Data Collection Script
# Optimized for Cost Efficiency, Representativeness, and Reproducibility
#
# This script orchestrates a stratified sampling workflow using the
# monthly balanced function to ensure temporal uniformity.
#
# Authors: Miguelangel Palma | Juan Jose Echeverry | Luis Eduardo Sandoval

# 1. Environment Configuration and Dependency Management ----------

## 1.1 Package Initialization ----------
### 1.1.1 Installation of Manager (pacman) ----------
if (!require("pacman")) install.packages("pacman")

### 1.1.2 Automated Library Loading ----------
pacman::p_load(
  httr2,      # Professional HTTP client
  tidyverse,  # Data manipulation (dplyr, ggplot2, etc.)
  lubridate,  # Date and time handling
  rlang       # Support for null-coalescing operators (%||%)
)

# 2. Security and Source Layer ----------

## 2.1 Credential Management ----------
### 2.1.1 External Configuration Source ----------
# Ensure Config.R defines the 'bearer_token' variable.
source(here::here("scripts", "api_data_extraction", "Autentificacion", "Config.R"))

## 2.2 Function Core Sourcing ----------
### 2.2.1 Loading External Modules ----------
# Sourcing the complete hierarchy of extraction functions.
source(here::here("scripts", "api_data_extraction", "Functions", "ScrapingFunctions.R"))

# 3. Research Design and Temporal Parameters ----------

## 3.1 Temporal Scope Definition ----------
### 3.1.1 Target Period Selection ----------
year  <- 2022
month <- 9

## 3.2 Sampling Strategy ----------
### 3.2.1 Monthly Target Specification ----------
# Strategic target for balanced daily representation.
# October has 31 days: base = floor(396/31) = 12, remainder = 396 - 12*31 = 24
# → 24 days get 13 tweets, 7 days get 12 tweets (sum = 396)
target_monthly_total <- 300

# 4. Search Query Engineering (Query Design) ----------

## 4.1 Syntax and Filter Optimization ----------
### 4.1.1 Entity Targeting (Gustavo Petro) ----------
#### 4.1.1.1 Operator Implementation ----------
# Filters ensure relevant, original Spanish tweets, excluding noise.
query_string <- paste(
  '("Gustavo Petro" OR @petrogustavo)',
  'lang:es',
  '-is:retweet',
  '-is:reply',
  '-is:quote',
  '-has:links'
)

# 5. Execution Layer (High-Level Orchestration) ----------

## 5.1 Automated Monthly Extraction ----------
### 5.1.1 Balanced Stratified Execution ----------
# Calling the master function that manages daily quotas and error handling.
extraction_result <- fetch_month_balanced(
  query          = query_string,
  year           = year,
  month          = month,
  total_target   = target_monthly_total,
  bearer_token   = bearer_token,
  verbose        = TRUE
)

# 6. Post-Processing and Integrity Layer ----------

## 6.1 Integrity Validation ----------
### 6.1.1 Extraction Guard ----------
# Stop execution if the extraction returned no data, preventing
# empty files from being written to disk.
if (!isTRUE(extraction_result$total_obtained > 0)) {
  stop(sprintf(
    "Extraction returned 0 tweets for %d-%02d. Check cost_audit for details.",
    year, month
  ))
}

## 6.2 Data Consolidation ----------
### 6.2.1 Extraction from Result Object ----------
final_dataset <- extraction_result$data

## 6.3 Data Cleansing ----------
### 6.3.1 Formatting and Type Casting ----------
#### 6.3.1.1 Final Normalization ----------
saveRDS(
  list(
    data       = final_dataset,
    cost_audit = extraction_result$cost_audit
  ),
  here::here(
    file.path(
      "data",
      "Scraping",
      "RawData",
      "rds",
      sprintf("twitter_cache_%d_%02d.rds", year, month)
    )
  )
)

# 7. Persistence and Storage ----------

## 7.1 Serialization ----------
### 7.1.1 Full Run Cache (data + audit) ----------
# Persists both the tweet dataset and the cost audit for full reproducibility.


## 7.2 Flat File Export ----------
### 7.2.1 CSV Generation for Interoperability ----------
csv_output_dir <- here::here("data", "raw", "twitter", "Opinión sobre Petro")
dir.create(csv_output_dir, recursive = TRUE, showWarnings = FALSE)

write_csv(
  final_dataset,
  file.path(csv_output_dir, sprintf("twitter_sample_%d_%02d.csv", year, month))
)
