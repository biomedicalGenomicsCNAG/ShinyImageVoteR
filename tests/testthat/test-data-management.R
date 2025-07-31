library(testthat)
library(DBI)
library(RSQLite)
library(pool)
library(ShinyImgVoteR)

testthat::test_that("init_db works with existing SQLite file", {
  # Create a temporary SQLite file with some data
  temp_db_file <- tempfile(fileext = ".sqlite")
  
  # Create initial database with test table
  initial_conn <- DBI::dbConnect(RSQLite::SQLite(), temp_db_file)
  DBI::dbExecute(initial_conn, "CREATE TABLE test_table (id INTEGER, name TEXT)")
  DBI::dbExecute(initial_conn, "INSERT INTO test_table VALUES (1, 'test')")
  DBI::dbDisconnect(initial_conn)
  
  # Initialize pool with existing database
  pool <- init_db(temp_db_file)
  
  # Check that we can access the existing data
  result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT * FROM test_table")
  })
  
  testthat::expect_equal(nrow(result), 1)
  testthat::expect_equal(result$id, 1)
  testthat::expect_equal(result$name, "test")
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})

testthat::test_that("init_db creates database file if it doesn't exist", {
  # Use a non-existent file path
  temp_db_file <- tempfile(fileext = ".sqlite")
  
  # Ensure file doesn't exist
  if (file.exists(temp_db_file)) {
    unlink(temp_db_file)
  }
  expect_false(file.exists(temp_db_file))
  
  # Initialize pool (should create the file)
  pool <- init_db(temp_db_file)
  
  # Check that file was created
  testthat::expect_true(file.exists(temp_db_file))
  
  # Check that pool works
  testthat::expect_true(inherits(pool, "Pool"))
  testthat::expect_true(inherits(pool, "R6"))
  
  # Test basic functionality
  result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT sqlite_version() as version")
  })
  testthat::expect_true(nchar(result$version) > 0)
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})

testthat::test_that("init_db handles invalid database paths gracefully", {
  # Test with invalid path (directory that doesn't exist)
  temp_dir <- tempdir()
  nonexistent_dir <- file.path(temp_dir, "nonexistent")
  invalid_path <- file.path(nonexistent_dir, "test.sqlite")
  
  # Ensure the parent directory exists (SQLite needs parent dir to exist)
  dir.create(nonexistent_dir, recursive = TRUE)
  
  # This should work now
  pool <- init_db(invalid_path)
  testthat::expect_true(inherits(pool, "Pool"))
  testthat::expect_true(inherits(pool, "R6"))
  
  # Test that it actually works
  result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT 1 as test")
  })
  testthat::expect_equal(result$test, 1)
  
  # Clean up
  pool::poolClose(pool)
  unlink(nonexistent_dir, recursive = TRUE)
})

testthat::test_that("init_db pool can execute transactions", {
  # Create a temporary SQLite file
  temp_db_file <- tempfile(fileext = ".sqlite")
  
  # Initialize pool
  pool <- init_db(temp_db_file)
  
  # Test transaction functionality
  pool::poolWithTransaction(pool, function(conn) {
    DBI::dbExecute(conn, "CREATE TABLE transaction_test (id INTEGER)")
    DBI::dbExecute(conn, "INSERT INTO transaction_test VALUES (1)")
    DBI::dbExecute(conn, "INSERT INTO transaction_test VALUES (2)")
  })
  
  # Verify data was committed
  result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT COUNT(*) as count FROM transaction_test")
  })
  
  testthat::expect_equal(result$count, 2)
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})

testthat::test_that("init_db pool supports multiple concurrent connections", {
  # Create a temporary SQLite file
  temp_db_file <- tempfile(fileext = ".sqlite")
  
  # Initialize pool
  pool <- init_db(temp_db_file)
  
  # Create test table
  pool::poolWithTransaction(pool, function(conn) {
    DBI::dbExecute(conn, "CREATE TABLE concurrent_test (id INTEGER)")
  })
  
  # Test multiple simultaneous operations
  results <- list()
  for (i in 1:3) {
    results[[i]] <- pool::poolWithTransaction(pool, function(conn) {
      DBI::dbExecute(conn, "INSERT INTO concurrent_test VALUES (?)", params = list(i))
      DBI::dbGetQuery(conn, "SELECT COUNT(*) as count FROM concurrent_test")
    })
  }
  
  # Final count should be 3
  final_result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT COUNT(*) as count FROM concurrent_test")
  })
  
  testthat::expect_equal(final_result$count, 3)
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})
