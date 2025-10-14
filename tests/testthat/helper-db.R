library(DBI)
library(RSQLite)
library(pool)

create_mock_db <- function() {
  db_file <- tempfile(fileext = ".sqlite")
  db_pool <- pool::dbPool(RSQLite::SQLite(), dbname = db_file)

  conn <- pool::poolCheckout(db_pool)
  on.exit(pool::poolReturn(conn), add = TRUE) # Ensure return no matter what

  # Create annotations table (removed PRIMARY KEY to allow duplicate coordinates)
  DBI::dbExecute(conn, "
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

  # Insert test data including duplicate coordinates with different REF/ALT
  test_mutations <- list(
    list("chr1:1000", "A", "T", "SNV", "/test/path1.png"),
    list("chr2:2000", "G", "C", "SNV", "/test/path2.png"),
    list("chr2:2000", "C", "A", "SNV", "/test/path2b.png"),  # Duplicate coordinate
    list("chr3:3000", "AT", "A", "DEL", "/test/path3.png")
  )

  for (mutation in test_mutations) {
    DBI::dbExecute(conn, "
      INSERT INTO annotations (coordinates, REF, ALT, variant, path)
      VALUES (?, ?, ?, ?, ?)
    ", params = mutation)
  }

  # Create sessionids table
  DBI::dbExecute(conn, "
    CREATE TABLE sessionids (
      userid TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")

  DBI::dbExecute(conn, "
    CREATE TABLE passwords (
      userid TEXT PRIMARY KEY,
      institute TEXT,
      password TEXT,
      pwd_retrieval_token TEXT,
      pwd_retrieved_timestamp TEXT
    )
  ")

  return(list(pool = db_pool, file = db_file))
}
