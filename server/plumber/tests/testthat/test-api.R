library(testthat)
library(plumber)
library(httr) # For actual HTTP requests if direct calls are problematic
library(jsonlite)
library(DBI)
library(RSQLite)

# --- Test Database Setup ---
# Path for the test database. api.R looks for "../voting_app.db".
# If test-api.R is in server/plumber/tests/testthat/, then api.R is at ../../api.R
# So, api.R's "../voting_app.db" becomes server/plumber/tests/voting_app.db
TEST_DB_FILE_FOR_API <- "../voting_app.db" # Path relative to api.R's location, but resolved from test dir
# Actual path from this test file's perspective:
ACTUAL_TEST_DB_PATH <- file.path(getwd(), TEST_DB_FILE_FOR_API)
# This needs to be managed carefully. If getwd() is server/plumber/tests/testthat,
# then ACTUAL_TEST_DB_PATH will be server/plumber/tests/testthat/../voting_app.db which is server/plumber/tests/voting_app.db

# Ensure the directory for the test DB exists if it's not the immediate parent
test_db_dir <- dirname(ACTUAL_TEST_DB_PATH)
if (!dir.exists(test_db_dir)) {
  dir.create(test_db_dir, recursive = TRUE)
}
message(paste("INFO: Test DB actual path will be:", ACTUAL_TEST_DB_PATH))


initialize_test_db <- function(data_list = list()) {
  # Ensure the correct path is used by deleting it first.
  if (file.exists(ACTUAL_TEST_DB_PATH)) {
    file.remove(ACTUAL_TEST_DB_PATH)
    message(paste("INFO: Removed existing test DB at:", ACTUAL_TEST_DB_PATH))
  }

  conn <- dbConnect(SQLite(), ACTUAL_TEST_DB_PATH)
  message(paste("INFO: Initialized test DB at:", ACTUAL_TEST_DB_PATH))

  # Create screenshots table
  dbExecute(conn, "
    CREATE TABLE screenshots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      coordinates TEXT NOT NULL,
      ref TEXT NOT NULL,
      alt TEXT NOT NULL,
      type_of_variant TEXT NOT NULL,
      path_to_screenshot TEXT NOT NULL UNIQUE,
      votes INTEGER NOT NULL DEFAULT 0
    )
  ")
  # Create votes table (for detailed logging in /api/votes)
  dbExecute(conn, "
    CREATE TABLE IF NOT EXISTS votes (
        id TEXT PRIMARY KEY,
        image_id INTEGER,
        rating INTEGER
    )")

  if (length(data_list) > 0) {
    for (item_data in data_list) {
      # Ensure item_data has names corresponding to columns, or adjust insert statement
      # For now, assume item_data is a named list/vector: list(id=1, coordinates="c1", ...)
      # If 'id' is part of item_data and is NULL or to be auto-incremented, don't include it in query_fields.
      query_fields <- names(item_data)
      query_values_placeholders <- paste0(":", query_fields, collapse = ", ")

      # Handle cases where id might be provided for specific test setups
      # If id is meant to be autoincremented, it should not be in item_data or be NULL
      # For simplicity, if id is provided, we use it.

      stmt <- paste0("INSERT INTO screenshots (", paste(query_fields, collapse = ", "), ") VALUES (", query_values_placeholders, ")")
      dbExecute(conn, stmt, params = item_data)
    }
    message(sprintf("INFO: Inserted %d rows into test DB screenshots table.", length(data_list)))
  }
  dbDisconnect(conn)
}

cleanup_test_db <- function() {
  if (file.exists(ACTUAL_TEST_DB_PATH)) {
    file.remove(ACTUAL_TEST_DB_PATH)
    message(paste("INFO: Cleaned up test DB at:", ACTUAL_TEST_DB_PATH))
  }
}

# --- Plumber API Loading ---
# Path to api.R from this test file (server/plumber/tests/testthat/test-api.R)
api_file_path <- "../../api.R"
if (!file.exists(api_file_path)) {
    stop(paste("FATAL: api.R not found at expected path:", file.path(getwd(), api_file_path)))
}
# The plumber router. db connection inside api.R will use its relative path.
# This means api.R will try to connect to server/plumber/tests/voting_app.db
# which is what ACTUAL_TEST_DB_PATH points to.
pr <- plumb(api_file_path)

# --- Tests ---

context("GET /api/images/next")

test_that("/api/images/next returns an image if available", {
  initialize_test_db(list(
    list(id = 1, coordinates = "c1", ref = "A", alt = "T", type_of_variant = "SNV", path_to_screenshot = "p1.png", votes = 0),
    list(id = 2, coordinates = "c2", ref = "G", alt = "C", type_of_variant = "SNV", path_to_screenshot = "p2.png", votes = 2)
  ))

  req <- list(REQUEST_METHOD = "GET", PATH_INFO = "/api/images/next", HTTP_HOST = "test")
  res <- pr$call(req)

  expect_equal(res$status, 200)
  body <- fromJSON(res$body)
  expect_true("id" %in% names(body))
  expect_true("url" %in% names(body))
  expect_true(body$url %in% c("p1.png", "p2.png"))
  cleanup_test_db()
})

test_that("/api/images/next returns 404 if all images have >= 3 votes", {
  initialize_test_db(list(
    list(id = 1, coordinates = "c1", ref = "A", alt = "T", type_of_variant = "SNV", path_to_screenshot = "p1.png", votes = 3),
    list(id = 2, coordinates = "c2", ref = "G", alt = "C", type_of_variant = "SNV", path_to_screenshot = "p2.png", votes = 5)
  ))

  req <- list(REQUEST_METHOD = "GET", PATH_INFO = "/api/images/next", HTTP_HOST = "test")
  res <- pr$call(req)

  expect_equal(res$status, 404)
  body <- fromJSON(res$body)
  expect_true("error" %in% names(body))
  cleanup_test_db()
})

test_that("/api/images/next returns 404 if database is empty", {
  initialize_test_db(list()) # Empty DB

  req <- list(REQUEST_METHOD = "GET", PATH_INFO = "/api/images/next", HTTP_HOST = "test")
  res <- pr$call(req)

  expect_equal(res$status, 404)
  body <- fromJSON(res$body)
  expect_true("error" %in% names(body))
  cleanup_test_db()
})


context("POST /api/votes")

test_that("/api/votes correctly increments votes and logs", {
  initialize_test_db(list(
    list(id = 10, coordinates = "c10", ref = "A", alt = "T", type_of_variant = "SNV", path_to_screenshot = "p10.png", votes = 1)
  ))

  vote_body <- list(image_id = 10, rating = 4)
  req <- list(
    REQUEST_METHOD = "POST",
    PATH_INFO = "/api/votes",
    HTTP_HOST = "test",
    body = toJSON(vote_body, auto_unbox = TRUE), # plumber needs the body as a string
    `CONTENT_TYPE` = "application/json" # Important for plumber to parse JSON body
  )
  # For plumber to correctly parse the JSON body from req$body, it often relies on
  # the prb_body element or specific handling for testing.
  # Let's try setting prb_body, which plumber might use internally for testing.
  req$prb_body <- req$body

  res <- pr$call(req)

  expect_equal(res$status, 200) # Expect success
  body <- fromJSON(res$body)
  expect_true(grepl("Vote registered and logged successfully", body$message))
  expect_equal(body$image_id, 10)

  # Verify database state
  conn <- dbConnect(SQLite(), ACTUAL_TEST_DB_PATH)
  updated_screenshot <- dbGetQuery(conn, "SELECT votes FROM screenshots WHERE id = 10")
  expect_equal(updated_screenshot$votes[1], 2)

  vote_log <- dbGetQuery(conn, "SELECT rating FROM votes WHERE image_id = 10")
  expect_equal(nrow(vote_log), 1)
  expect_equal(vote_log$rating[1], 4)
  dbDisconnect(conn)

  cleanup_test_db()
})

test_that("/api/votes handles non-existent image_id", {
  initialize_test_db(list(
    list(id = 1, coordinates = "c1", ref = "A", alt = "T", type_of_variant = "SNV", path_to_screenshot = "p1.png", votes = 1)
  ))

  vote_body <- list(image_id = 999, rating = 4) # Non-existent ID
  req <- list(
    REQUEST_METHOD = "POST", PATH_INFO = "/api/votes", HTTP_HOST = "test",
    body = toJSON(vote_body, auto_unbox = TRUE),
    `CONTENT_TYPE` = "application/json"
  )
  req$prb_body <- req$body

  res <- pr$call(req)

  # The API currently logs a warning for non-existent ID but doesn't return an error status for that alone.
  # It proceeds to attempt logging if rating is provided.
  # The 'update_successful' flag in the response will indicate no rows were affected.
  expect_equal(res$status, 200) # or 500 if dbExecute fails hard, but it doesn't for 0 rows updated
  body <- fromJSON(res$body)
  expect_true(grepl("Screenshot vote count NOT updated or image_id not found", body$update_status))

  # Verify that the original image's votes are unchanged
  conn <- dbConnect(SQLite(), ACTUAL_TEST_DB_PATH)
  original_screenshot <- dbGetQuery(conn, "SELECT votes FROM screenshots WHERE id = 1")
  expect_equal(original_screenshot$votes[1], 1)
  dbDisconnect(conn)

  cleanup_test_db()
})

test_that("/api/votes handles missing rating (vote increment only)", {
  initialize_test_db(list(
    list(id = 20, coordinates = "c20", ref = "N", alt = "G", type_of_variant = "SNV", path_to_screenshot = "p20.png", votes = 0)
  ))

  vote_body <- list(image_id = 20) # Rating explicitly missing
  req <- list(
    REQUEST_METHOD = "POST", PATH_INFO = "/api/votes", HTTP_HOST = "test",
    body = toJSON(vote_body, auto_unbox = TRUE),
    `CONTENT_TYPE` = "application/json"
  )
  req$prb_body <- req$body
  res <- pr$call(req)

  expect_equal(res$status, 200)
  body <- fromJSON(res$body)
  expect_true(grepl("Vote count updated successfully. No rating provided for detailed logging.", body$message))
  expect_equal(body$image_id, 20)

  conn <- dbConnect(SQLite(), ACTUAL_TEST_DB_PATH)
  updated_screenshot <- dbGetQuery(conn, "SELECT votes FROM screenshots WHERE id = 20")
  expect_equal(updated_screenshot$votes[1], 1)

  vote_log_count <- dbGetQuery(conn, "SELECT COUNT(*) AS count FROM votes WHERE image_id = 20")
  expect_equal(vote_log_count$count[1], 0) # No detailed log
  dbDisconnect(conn)

  cleanup_test_db()
})

# Add more tests: e.g., invalid rating value, etc.

message("INFO: All R tests in test-api.R completed.")

# Final cleanup, just in case a test failed before its own cleanup
# withr::defer(cleanup_test_db(), envir = .GlobalEnv) # Better for robust cleanup
# For now, simple call:
# cleanup_test_db() # This might run too early if tests are asynchronous or if test_dir runs this file multiple times.
# It's generally better to clean up within each test_that or use testthat's local fixtures.
# The current setup calls cleanup_test_db() at the end of each test_that block.
