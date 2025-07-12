library(testthat)
library(B1MGVariantVoting)

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
