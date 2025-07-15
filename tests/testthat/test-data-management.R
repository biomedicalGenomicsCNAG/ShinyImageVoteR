library(testthat)
library(DBI)
library(RSQLite)
library(pool)
library(ShinyImgVoteR)

test_that("get_user_data_dir creates directory when it does not exist", {
  # Create a temporary directory for testing
  temp_base <- tempdir()
  test_base <- file.path(temp_base, "test_data_mgmt")
  
  # Clean up any existing test directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Create base directory
  dir.create(test_base, recursive = TRUE)
  
  # Test creating user_data directory
  user_data_dir <- get_user_data_dir(test_base)
  
  # Check that the directory was created and path is correct
  expected_path <- file.path(test_base, "user_data")
  expect_equal(user_data_dir, expected_path)
  expect_true(dir.exists(user_data_dir))
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

test_that("get_user_data_dir returns existing directory path", {
  # Create a temporary directory for testing
  temp_base <- tempdir()
  test_base <- file.path(temp_base, "test_existing")
  
  # Clean up any existing test directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Create base directory and user_data directory
  user_data_path <- file.path(test_base, "user_data")
  dir.create(user_data_path, recursive = TRUE)
  expect_true(dir.exists(user_data_path))
  
  # Test that function returns existing directory
  result <- get_user_data_dir(test_base)
  
  expect_equal(result, user_data_path)
  expect_true(dir.exists(result))
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

test_that("get_user_data_dir uses current working directory when base_dir is NULL", {
  # Save current working directory
  original_wd <- getwd()
  
  # Create a temporary directory and change to it
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "test_cwd")
  dir.create(test_dir, recursive = TRUE)
  setwd(test_dir)
  
  # Clean up any existing user_data directory
  user_data_path <- file.path(test_dir, "user_data")
  if (dir.exists(user_data_path)) {
    unlink(user_data_path, recursive = TRUE)
  }
  
  # Test with NULL base_dir
  result <- get_user_data_dir(NULL)
  
  # Should create user_data in current working directory
  expected_path <- file.path(getwd(), "user_data")
  expect_equal(result, expected_path)
  expect_true(dir.exists(result))
  
  # Restore original working directory
  setwd(original_wd)
  
  # Clean up
  unlink(test_dir, recursive = TRUE)
})

test_that("get_user_data_dir handles nested directory creation", {
  # Create a temporary directory for testing
  temp_base <- tempdir()
  test_base <- file.path(temp_base, "test_nested", "deep", "path")
  
  # Clean up any existing test directory
  if (dir.exists(file.path(temp_base, "test_nested"))) {
    unlink(file.path(temp_base, "test_nested"), recursive = TRUE)
  }
  
  # Test creating user_data directory in deep nested path
  user_data_dir <- get_user_data_dir(test_base)
  
  # Check that the nested directory structure was created
  expected_path <- file.path(test_base, "user_data")
  expect_equal(user_data_dir, expected_path)
  expect_true(dir.exists(user_data_dir))
  expect_true(dir.exists(test_base))
  
  # Clean up
  unlink(file.path(temp_base, "test_nested"), recursive = TRUE)
})

test_that("get_user_data_dir handles special characters in paths", {
  # Create a temporary directory for testing
  temp_base <- tempdir()
  test_base <- file.path(temp_base, "test_special chars & symbols")
  
  # Clean up any existing test directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Create base directory
  dir.create(test_base, recursive = TRUE)
  
  # Test creating user_data directory with special characters in path
  user_data_dir <- get_user_data_dir(test_base)
  
  # Check that the directory was created correctly
  expected_path <- file.path(test_base, "user_data")
  expect_equal(user_data_dir, expected_path)
  expect_true(dir.exists(user_data_dir))
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

test_that("get_user_data_dir works with relative paths", {
  # Save current working directory
  original_wd <- getwd()
  
  # Create a temporary directory and change to it
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "test_relative")
  dir.create(test_dir, recursive = TRUE)
  setwd(test_dir)
  
  # Create a relative path
  rel_path <- "relative_test"
  dir.create(rel_path, recursive = TRUE)
  
  # Test with relative path
  user_data_dir <- get_user_data_dir(rel_path)
  
  # Check that the directory was created
  expected_path <- file.path(rel_path, "user_data")
  expect_equal(user_data_dir, expected_path)
  expect_true(dir.exists(user_data_dir))
  
  # Restore original working directory
  setwd(original_wd)
  
  # Clean up
  unlink(test_dir, recursive = TRUE)
})

test_that("get_user_data_dir is idempotent", {
  # Create a temporary directory for testing
  temp_base <- tempdir()
  test_base <- file.path(temp_base, "test_idempotent")
  
  # Clean up any existing test directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Create base directory
  dir.create(test_base, recursive = TRUE)
  
  # Call function multiple times
  result1 <- get_user_data_dir(test_base)
  result2 <- get_user_data_dir(test_base)
  result3 <- get_user_data_dir(test_base)
  
  # All results should be identical
  expect_equal(result1, result2)
  expect_equal(result2, result3)
  
  # Directory should exist and be the same
  expected_path <- file.path(test_base, "user_data")
  expect_equal(result1, expected_path)
  expect_true(dir.exists(result1))
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

test_that("get_user_data_dir handles empty string base_dir", {
  # Save current working directory
  original_wd <- getwd()
  
  # Create a temporary directory and change to it
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "test_empty_string")
  dir.create(test_dir, recursive = TRUE)
  setwd(test_dir)
  
  # Test with empty string (should be treated as current directory)
  user_data_dir <- get_user_data_dir("")
  
  # Should create user_data in current working directory
  expected_path <- file.path(getwd(), "user_data")
  expect_equal(user_data_dir, expected_path)
  expect_true(dir.exists(user_data_dir))
  
  # Restore original working directory
  setwd(original_wd)
  
  # Clean up
  unlink(test_dir, recursive = TRUE)
})

test_that("get_user_data_dir preserves permissions on existing directory", {
  # Create a temporary directory for testing
  temp_base <- tempdir()
  test_base <- file.path(temp_base, "test_permissions")
  
  # Clean up any existing test directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Create base directory and user_data directory
  user_data_path <- file.path(test_base, "user_data")
  dir.create(user_data_path, recursive = TRUE)
  
  # Get initial directory info
  initial_info <- file.info(user_data_path)
  
  # Call function on existing directory
  result <- get_user_data_dir(test_base)
  
  # Check that directory info is preserved
  final_info <- file.info(user_data_path)
  expect_equal(result, user_data_path)
  expect_equal(initial_info$mtime, final_info$mtime)
  expect_equal(initial_info$mode, final_info$mode)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Tests for init_db function
test_that("init_db creates a valid database connection pool", {
  # Create a temporary SQLite file
  temp_db_file <- tempfile(fileext = ".sqlite")
  
  # Initialize the database pool
  pool <- init_db(temp_db_file)
  
  # Check that pool is created and is a Pool object (R6 class)
  expect_true(inherits(pool, "Pool"))
  expect_true(inherits(pool, "R6"))
  
  # Test that we can query the database (should work even with empty database)
  result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT 1 as test")
  })
  expect_equal(result$test, 1)
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})

test_that("init_db works with existing SQLite file", {
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
  
  expect_equal(nrow(result), 1)
  expect_equal(result$id, 1)
  expect_equal(result$name, "test")
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})

test_that("init_db creates database file if it doesn't exist", {
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
  expect_true(file.exists(temp_db_file))
  
  # Check that pool works
  expect_true(inherits(pool, "Pool"))
  expect_true(inherits(pool, "R6"))
  
  # Test basic functionality
  result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT sqlite_version() as version")
  })
  expect_true(nchar(result$version) > 0)
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})

test_that("init_db handles invalid database paths gracefully", {
  # Test with invalid path (directory that doesn't exist)
  temp_dir <- tempdir()
  nonexistent_dir <- file.path(temp_dir, "nonexistent")
  invalid_path <- file.path(nonexistent_dir, "test.sqlite")
  
  # Ensure the parent directory exists (SQLite needs parent dir to exist)
  dir.create(nonexistent_dir, recursive = TRUE)
  
  # This should work now
  pool <- init_db(invalid_path)
  expect_true(inherits(pool, "Pool"))
  expect_true(inherits(pool, "R6"))
  
  # Test that it actually works
  result <- pool::poolWithTransaction(pool, function(conn) {
    DBI::dbGetQuery(conn, "SELECT 1 as test")
  })
  expect_equal(result$test, 1)
  
  # Clean up
  pool::poolClose(pool)
  unlink(nonexistent_dir, recursive = TRUE)
})

test_that("init_db pool can execute transactions", {
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
  
  expect_equal(result$count, 2)
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})

test_that("init_db pool supports multiple concurrent connections", {
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
  
  expect_equal(final_result$count, 3)
  
  # Clean up
  pool::poolClose(pool)
  unlink(temp_db_file)
})
