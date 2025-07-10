#' Database Utility Functions
#'
#' Utility functions for database operations in the B1MG Variant Voting application.
#'
#' @name db_utils
NULL

#' Create a test database pool
#'
#' Creates a temporary SQLite database pool for testing purposes.
#'
#' @return List containing pool object and database file path
#' @export
create_test_db_pool <- function() {
  db_file <- tempfile(fileext = ".sqlite")
  pool <- pool::dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create required tables
  DBI::dbExecute(pool, "
    CREATE TABLE annotations (
      coordinates TEXT,
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
  
  DBI::dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Insert some test data
  DBI::dbExecute(pool, "
    INSERT INTO annotations (coordinates, REF, ALT, variant, path)
    VALUES 
      ('chr1:1000', 'A', 'T', 'SNV', '/path/to/image1.png'),
      ('chr2:2000', 'G', 'C', 'SNV', '/path/to/image2.png'),
      ('chr3:3000', 'AT', 'A', 'DEL', '/path/to/image3.png')
  ")
  
  return(list(pool = pool, file = db_file))
}

#' Generate randomization seed
#'
#' Generates a consistent randomization seed based on user ID and timestamp.
#'
#' @param user_id Character. The user ID
#' @param timestamp Numeric. Optional timestamp (uses current time if not provided)
#' @return Integer. The generated seed
#' @export
generate_user_seed <- function(user_id, timestamp = NULL) {
  if (is.null(timestamp)) {
    timestamp <- as.numeric(Sys.time())
  }
  
  combined <- paste0(user_id, timestamp)
  seed <- strtoi(substr(digest::digest(combined, algo = "crc32"), 1, 7), base = 16)
  return(seed)
}
