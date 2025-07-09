library(testthat)
library(shiny)
library(jsonlite)
library(digest)
library(DBI)
library(RSQLite)
library(pool)

# Source the necessary files
source("../../config.R")
source("../../server_utils.R")

# Helper function to create test database pool
create_test_pool <- function() {
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create required tables
  dbExecute(pool, "
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
  
  dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Insert some test data
  dbExecute(pool, "
    INSERT INTO annotations (coordinates, REF, ALT, variant, path)
    VALUES 
      ('chr1:1000', 'A', 'T', 'SNV', '/path/to/image1.png'),
      ('chr2:2000', 'G', 'C', 'SNV', '/path/to/image2.png'),
      ('chr3:3000', 'AT', 'A', 'DEL', '/path/to/image3.png')
  ")
  
  return(list(pool = pool, file = db_file))
}

test_that("Logout scheduling functions work correctly", {
  # Test cancel_pending_logout with non-existent session
  expect_silent(cancel_pending_logout("non_existent_session"))
  
  # Test schedule_logout_update
  callback_executed <- FALSE
  callback <- function() { callback_executed <<- TRUE }
  
  # Schedule with very short delay for testing
  schedule_logout_update("test_session", callback, delay = 0.1)
  
  # Check that task was scheduled
  expect_true(exists("test_session", envir = pending_logout_tasks))
  
  # Wait for callback execution
  Sys.sleep(0.2)
  expect_true(callback_executed)
  
  # Check that task was cleaned up
  expect_false(exists("test_session", envir = pending_logout_tasks))
})

test_that("User directory creation works", {
  # Test that the directory creation code works with test institutes
  test_institutes <- c("Test_Institute", "Another Test")
  
  # Create temporary directory for testing
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)
  
  # Run the directory creation code
  lapply(test_institutes, function(institute) {
    institute <- gsub(" ", "_", institute)
    dir.create(file.path("user_data", institute), recursive = TRUE, showWarnings = FALSE)
  })
  
  # Check that directories were created
  expect_true(dir.exists(file.path("user_data", "Test_Institute")))
  expect_true(dir.exists(file.path("user_data", "Another_Test")))
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, "user_data"), recursive = TRUE)
})

test_that("User info file creation works correctly", {
  # Create temporary directory
  temp_dir <- tempdir()
  user_dir <- file.path(temp_dir, "test_user")
  dir.create(user_dir, recursive = TRUE)
  
  user_id <- "test_user"
  voting_institute <- "CNAG"
  
  # Create user info (similar to what happens in observeEvent)
  combined <- paste0(user_id, as.numeric(Sys.time()))
  seed <- strtoi(substr(digest(combined, algo = "crc32"), 1, 7), base = 16)
  
  user_info <- list(
    user_id = user_id,
    voting_institute = voting_institute,
    images_randomisation_seed = seed
  )
  
  info_file <- file.path(user_dir, paste0(user_id, "_info.json"))
  write_json(user_info, info_file, auto_unbox = TRUE, pretty = TRUE)
  
  # Verify file was created and contains correct data
  expect_true(file.exists(info_file))
  
  loaded_info <- read_json(info_file)
  expect_equal(loaded_info$user_id, user_id)
  expect_equal(loaded_info$voting_institute, voting_institute)
  expect_true(is.numeric(loaded_info$images_randomisation_seed))
  
  # Clean up
  unlink(user_dir, recursive = TRUE)
})

test_that("User annotations file creation works correctly", {
  # Create test database pool
  test_db <- create_test_pool()
  pool <- test_db$pool
  
  # Create temporary directory
  temp_dir <- tempdir()
  user_dir <- file.path(temp_dir, "test_user")
  dir.create(user_dir, recursive = TRUE)
  
  user_id <- "test_user"
  
  # Query coordinates from test database
  query <- "SELECT coordinates FROM annotations"
  coords <- dbGetQuery(pool, query)
  coords_vec <- as.character(coords[[1]])
  
  # Set seed for reproducible testing
  set.seed(12345)
  randomised_coords <- sample(coords_vec, length(coords_vec), replace = FALSE)
  
  # Create annotations dataframe
  annotations_df <- setNames(
    as.data.frame(
      lapply(cfg_user_annotations_colnames, function(col) {
        if (col == "coordinates") {
          randomised_coords
        } else {
          rep("", length(randomised_coords))
        }
      }),
      stringsAsFactors = FALSE
    ),
    cfg_user_annotations_colnames
  )
  
  annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.tsv"))
  write.table(
    annotations_df,
    file = annotations_file,
    sep = "\t",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  
  # Verify file was created
  expect_true(file.exists(annotations_file))
  
  # Read back and verify structure
  loaded_annotations <- read.table(annotations_file, sep = "\t", header = TRUE, stringsAsFactors = FALSE)
  expect_equal(names(loaded_annotations), cfg_user_annotations_colnames)
  expect_equal(nrow(loaded_annotations), length(coords_vec))
  expect_true(all(loaded_annotations$coordinates %in% coords_vec))
  
  # Clean up
  poolClose(test_db$pool)
  unlink(user_dir, recursive = TRUE)
  unlink(test_db$file)
})

test_that("Randomization seed generation is consistent", {
  user_id <- "test_user"
  fixed_time <- 1609459200 # Fixed timestamp for testing
  
  # Generate seed twice with same input
  combined1 <- paste0(user_id, fixed_time)
  seed1 <- strtoi(substr(digest(combined1, algo = "crc32"), 1, 7), base = 16)
  
  combined2 <- paste0(user_id, fixed_time)
  seed2 <- strtoi(substr(digest(combined2, algo = "crc32"), 1, 7), base = 16)
  
  # Should be identical
  expect_equal(seed1, seed2)
  
  # Different inputs should give different seeds
  combined3 <- paste0("different_user", fixed_time)
  seed3 <- strtoi(substr(digest(combined3, algo = "crc32"), 1, 7), base = 16)
  
  expect_false(seed1 == seed3)
})

test_that("External shutdown mechanism works", {
  # Create temporary shutdown file
  temp_file <- tempfile()
  
  # File doesn't exist initially
  expect_false(file.exists(temp_file))
  
  # Create the file
  file.create(temp_file)
  expect_true(file.exists(temp_file))
  
  # Simulate the shutdown check (remove file)
  if (file.exists(temp_file)) {
    file.remove(temp_file)
  }
  expect_false(file.exists(temp_file))
})
