library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(ShinyImgVoteR)

# locate the directory where inst/shiny-app was installed
# app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

# # source necessary files
# source(file.path(app_dir, "config.R"))

cfg <- ShinyImgVoteR::load_config(
  config_file_path = system.file(
    "shiny-app",
    "default_env",
    "config",
    "config.yaml",
    package = "ShinyImgVoteR"
  )
)

testthat::test_that("Database connection and queries work", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Test that we can query the database
  total_images <- dbGetQuery(test_pool, "SELECT COUNT(*) as n FROM annotations")$n
  testthat::expect_equal(total_images, 3)
  
  # Test coordinate retrieval
  coords_result <- dbGetQuery(test_pool, "SELECT coordinates FROM annotations")
  testthat::expect_equal(nrow(coords_result), 3)
  testthat::expect_true("chr1:1000" %in% coords_result$coordinates)
  testthat::expect_true("chr2:2000" %in% coords_result$coordinates)
  testthat::expect_true("chr3:3000" %in% coords_result$coordinates)
  
  # Test specific mutation retrieval
  specific_mutation <- dbGetQuery(test_pool, 
    "SELECT * FROM annotations WHERE coordinates = 'chr1:1000'")
  testthat::expect_equal(nrow(specific_mutation), 1)
  testthat::expect_equal(specific_mutation$REF, "A")
  testthat::expect_equal(specific_mutation$ALT, "T")
  testthat::expect_equal(specific_mutation$variant, "SNV")
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
})

testthat::test_that("Vote counting updates work correctly", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Test vote increment
  coordinates <- "chr1:1000"
  
  # Increment correct vote count
  DBI::dbExecute(test_pool, "
    UPDATE annotations 
    SET vote_count_correct = vote_count_correct + 1,
        vote_count_total = vote_count_total + 1
    WHERE coordinates = ?
  ", params = list(coordinates))
  
  # Verify the update
  result <- DBI::dbGetQuery(test_pool, "
    SELECT vote_count_correct, vote_count_total 
    FROM annotations 
    WHERE coordinates = ?
  ", params = list(coordinates))
  
  testthat::expect_equal(result$vote_count_correct, 1)
  testthat::expect_equal(result$vote_count_total, 1)
  
  # Test another vote type
  DBI::dbExecute(test_pool, "
    UPDATE annotations 
    SET vote_count_no_variant = vote_count_no_variant + 1,
        vote_count_total = vote_count_total + 1
    WHERE coordinates = ?
  ", params = list(coordinates))
  
  # Verify the update
  result <- DBI::dbGetQuery(test_pool, "
    SELECT vote_count_correct, vote_count_no_variant, vote_count_total 
    FROM annotations 
    WHERE coordinates = ?
  ", params = list(coordinates))
  
  testthat::expect_equal(result$vote_count_correct, 1)
  testthat::expect_equal(result$vote_count_no_variant, 1)
  testthat::expect_equal(result$vote_count_total, 2)
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
})

testthat::test_that("Database column mappings are correct", {
  # Test that vote mappings match database columns
  testthat::expect_equal(cfg$vote2dbcolumn_map$yes, "vote_count_correct")
  testthat::expect_equal(cfg$vote2dbcolumn_map$no, "vote_count_no_variant")
  testthat::expect_equal(cfg$vote2dbcolumn_map$diff_var, "vote_count_different_variant")
  testthat::expect_equal(cfg$vote2dbcolumn_map$not_confident, "vote_count_not_sure")
  
  # Test that all vote count columns are included in cfg_vote_counts_cols
  for (vote_col in cfg$vote2dbcolumn_map) {
    testthat::expect_true(vote_col %in% cfg$vote_counts_cols)
  }
  
  # Test that total column is included
  testthat::expect_true("vote_count_total" %in% cfg$vote_counts_cols)
})

testthat::test_that("Database schema matches configuration", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Get table schema
  schema <- dbGetQuery(test_pool, "PRAGMA table_info(annotations)")
  column_names <- schema$name
  
  # Test that all configured general columns exist
  for (col in cfg$db_general_cols) {
    testthat::expect_true(col %in% column_names, 
                info = paste("Column", col, "should exist in annotations table"))
  }
  
  # Test that all vote count columns exist
  for (col in cfg$vote_counts_cols) {
    testthat::expect_true(col %in% column_names,
                info = paste("Column", col, "should exist in annotations table"))
  }
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
})

testthat::test_that("Pool connection management works", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Test connection checkout/return
  conn <- pool::poolCheckout(test_pool)
  expect_s4_class(conn, "SQLiteConnection")
  
  # Test that we can use the connection
  result <- dbGetQuery(conn, "SELECT COUNT(*) as n FROM annotations")
  testthat::expect_equal(result$n, 3)
  
  # Return connection
  pool::poolReturn(conn)
  
  # Test pool close
  expect_silent(poolClose(test_pool))
  
  # Clean up
  unlink(mock_db$file)
})
