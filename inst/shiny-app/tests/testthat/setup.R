# Test setup and helper functions

library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(jsonlite)
library(digest)
library(dplyr)
library(tibble)

# Set up test environment
options(shiny.testmode = TRUE)

# Helper function to create a complete test database
create_complete_test_db <- function() {
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create annotations table
  dbExecute(pool, "
    CREATE TABLE annotations (
      coordinates TEXT PRIMARY KEY,
      REF TEXT,
      ALT TEXT,
      variant TEXT,
      path TEXT,
      vote_count_correct INTEGER DEFAULT 0,
      vote_count_no_variant INTEGER DEFAULT 0,
      vote_count_different_variant INTEGER DEFAULT 0,
      vote_count_not_sure INTEGER DEFAULT 0,
      vote_count_total INTEGER DEFAULT 0
    )
  ")
  
  # Create sessionids table
  dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Insert test mutations
  test_mutations <- list(
    list("chr1:1000", "A", "T", "SNV", "/test/images/mutation1.png"),
    list("chr2:2000", "G", "C", "SNV", "/test/images/mutation2.png"),
    list("chr3:3000", "AT", "A", "DEL", "/test/images/mutation3.png"),
    list("chr4:4000", "C", "CTG", "INS", "/test/images/mutation4.png"),
    list("chr5:5000", "GGG", "G", "DEL", "/test/images/mutation5.png")
  )
  
  for (mutation in test_mutations) {
    dbExecute(pool, "
      INSERT INTO annotations (coordinates, REF, ALT, variant, path)
      VALUES (?, ?, ?, ?, ?)
    ", params = mutation)
  }
  
  return(list(pool = pool, file = db_file))
}

# Helper function to create test user directory structure
create_test_user_structure <- function(base_dir = tempdir()) {
  test_structure <- list(
    base_dir = base_dir,
    user_data_dir = file.path(base_dir, "user_data"),
    institutes = c("CNAG", "Test_Institute"),
    users = c("test_user1", "test_user2")
  )
  
  # Create directory structure
  for (institute in test_structure$institutes) {
    for (user in test_structure$users) {
      user_dir <- file.path(test_structure$user_data_dir, institute, user)
      dir.create(user_dir, recursive = TRUE, showWarnings = FALSE)
    }
  }
  
  return(test_structure)
}

# Helper function to clean up test environment
cleanup_test_env <- function(test_db = NULL, test_dirs = NULL) {
  if (!is.null(test_db)) {
    if (!is.null(test_db$pool)) {
      poolClose(test_db$pool)
    }
    if (!is.null(test_db$file) && file.exists(test_db$file)) {
      unlink(test_db$file)
    }
  }
  
  if (!is.null(test_dirs)) {
    for (dir in test_dirs) {
      if (dir.exists(dir)) {
        unlink(dir, recursive = TRUE)
      }
    }
  }
}

# Mock configuration values for testing
test_cfg <- list(
  sqlite_file = ":memory:",
  institute_ids = c("Test_Institute", "CNAG", "DKFZ"),
  user_ids = c("test_user1", "test_user2"),
  credentials_df = data.frame(
    user = c("test_user1", "test_user2"),
    password = c("password1", "password2"),
    stringsAsFactors = FALSE
  ),
  application_title = "Test Variant Voting App",
  vote2dbcolumn_map = list(
    yes = "vote_count_correct",
    no = "vote_count_no_variant",
    diff_var = "vote_count_different_variant",
    not_confident = "vote_count_not_sure"
  ),
  user_annotations_colnames = c(
    "coordinates", "agreement", "alternative_vartype", 
    "observation", "comment", "shinyauthr_session_id", 
    "time_till_vote_casted_in_seconds"
  )
)

# Set up global test variables
if (!exists("pending_logout_tasks")) {
  pending_logout_tasks <- new.env(parent = emptyenv())
}
