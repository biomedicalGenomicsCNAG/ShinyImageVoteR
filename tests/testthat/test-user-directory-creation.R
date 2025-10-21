library(testthat)

test_that("create_user_directory creates institute and user directories", {
  # Create a temporary directory for testing
  temp_base <- tempfile(pattern = "test_user_dir_")
  dir.create(temp_base, recursive = TRUE)
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)
  
  # Test basic directory creation
  user_dir <- create_user_directory(temp_base, "institute1", "user1")
  
  # Check that both directories were created
  expect_true(dir.exists(file.path(temp_base, "institute1")))
  expect_true(dir.exists(file.path(temp_base, "institute1", "user1")))
  expect_equal(user_dir, file.path(temp_base, "institute1", "user1"))
})

test_that("create_user_directory handles existing institute directory", {
  # Create a temporary directory for testing
  temp_base <- tempfile(pattern = "test_user_dir_")
  dir.create(temp_base, recursive = TRUE)
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)
  
  # Create institute directory first
  institute_dir <- file.path(temp_base, "institute2")
  dir.create(institute_dir)
  
  # Now create user directory
  user_dir <- create_user_directory(temp_base, "institute2", "user2")
  
  # Check that user directory was created
  expect_true(dir.exists(file.path(temp_base, "institute2", "user2")))
  expect_equal(user_dir, file.path(temp_base, "institute2", "user2"))
})

test_that("create_user_directory handles existing user directory", {
  # Create a temporary directory for testing
  temp_base <- tempfile(pattern = "test_user_dir_")
  dir.create(temp_base, recursive = TRUE)
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)
  
  # Create both directories first
  user_dir_path <- file.path(temp_base, "institute3", "user3")
  dir.create(user_dir_path, recursive = TRUE)
  
  # Call create_user_directory - should not fail
  user_dir <- create_user_directory(temp_base, "institute3", "user3")
  
  # Check that directory still exists
  expect_true(dir.exists(user_dir_path))
  expect_equal(user_dir, user_dir_path)
})

test_that("create_user_directory validates institute name", {
  # Create a temporary directory for testing
  temp_base <- tempfile(pattern = "test_user_dir_")
  dir.create(temp_base, recursive = TRUE)
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)
  
  # Test with invalid institute name (contains spaces)
  expect_error(
    create_user_directory(temp_base, "my institute", "user1"),
    "Invalid institute name"
  )
  
  # Test with invalid institute name (contains special characters)
  expect_error(
    create_user_directory(temp_base, "institute-1", "user1"),
    "Invalid institute name"
  )
})

test_that("create_user_directory validates user ID", {
  # Create a temporary directory for testing
  temp_base <- tempfile(pattern = "test_user_dir_")
  dir.create(temp_base, recursive = TRUE)
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)
  
  # Test with invalid user ID (contains spaces)
  expect_error(
    create_user_directory(temp_base, "institute1", "my user"),
    "Invalid user ID"
  )
  
  # Test with invalid user ID (contains special characters)
  expect_error(
    create_user_directory(temp_base, "institute1", "user@1"),
    "Invalid user ID"
  )
})

test_that("create_user_directory creates multiple users in same institute", {
  # Create a temporary directory for testing
  temp_base <- tempfile(pattern = "test_user_dir_")
  dir.create(temp_base, recursive = TRUE)
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)
  
  # Create multiple users in the same institute
  user1_dir <- create_user_directory(temp_base, "institute4", "user1")
  user2_dir <- create_user_directory(temp_base, "institute4", "user2")
  user3_dir <- create_user_directory(temp_base, "institute4", "user3")
  
  # Check that all directories were created
  expect_true(dir.exists(file.path(temp_base, "institute4")))
  expect_true(dir.exists(file.path(temp_base, "institute4", "user1")))
  expect_true(dir.exists(file.path(temp_base, "institute4", "user2")))
  expect_true(dir.exists(file.path(temp_base, "institute4", "user3")))
  
  # Check that the returned paths are correct
  expect_equal(user1_dir, file.path(temp_base, "institute4", "user1"))
  expect_equal(user2_dir, file.path(temp_base, "institute4", "user2"))
  expect_equal(user3_dir, file.path(temp_base, "institute4", "user3"))
})

test_that("create_user_directory works with valid alphanumeric and underscore names", {
  # Create a temporary directory for testing
  temp_base <- tempfile(pattern = "test_user_dir_")
  dir.create(temp_base, recursive = TRUE)
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)
  
  # Test with valid names containing letters, numbers, and underscores
  user_dir <- create_user_directory(temp_base, "Institute_123", "User_456")
  
  # Check that directories were created
  expect_true(dir.exists(file.path(temp_base, "Institute_123")))
  expect_true(dir.exists(file.path(temp_base, "Institute_123", "User_456")))
  expect_equal(user_dir, file.path(temp_base, "Institute_123", "User_456"))
})
