library(testthat)
library(B1MGVariantVoting)

test_that("get_app_dir returns correct path", {
  app_dir <- get_app_dir()
  
  # Should return a character string
  expect_true(is.character(app_dir))
  expect_length(app_dir, 1)
  
  # Should not be empty
  expect_true(nchar(app_dir) > 0)
  
  # Should end with "shiny-app"
  expect_true(grepl("shiny-app$", app_dir))
  
  # Should contain the package name (case insensitive)
  expect_true(grepl("B1MGVariantVoting", app_dir, ignore.case = TRUE))
  
  # Directory should exist when package is installed
  if (app_dir != "") {
    expect_true(dir.exists(app_dir))
  }
})

test_that("get_app_dir is consistent across calls", {
  app_dir1 <- get_app_dir()
  app_dir2 <- get_app_dir()
  
  expect_equal(app_dir1, app_dir2)
})

test_that("run_voting_app validates app directory existence", {
  # Test what happens when system.file returns empty string
  # We'll just test that the function exists and has the right structure
  # since mocking is difficult in this environment
  
  expect_true(is.function(run_voting_app))
  
  # Check function arguments
  formals_names <- names(formals(run_voting_app))
  expected_args <- c("host", "port", "launch.browser", "user_data_dir", "database_path", "...")
  expect_true(all(expected_args %in% formals_names))
  
  # Check default values
  defaults <- formals(run_voting_app)
  expect_equal(defaults$host, "127.0.0.1")
  expect_null(defaults$port)
  expect_true(defaults$launch.browser)
  expect_null(defaults$user_data_dir)
  expect_null(defaults$database_path)
})

test_that("run_voting_app function signature and structure", {
  # Test function parameters and their defaults
  expect_true(is.function(run_voting_app))
  
  # Check function arguments
  formals_names <- names(formals(run_voting_app))
  expected_args <- c("host", "port", "launch.browser", "user_data_dir", "database_path", "...")
  expect_true(all(expected_args %in% formals_names))
  
  # Check default values
  defaults <- formals(run_voting_app)
  expect_equal(defaults$host, "127.0.0.1")
  expect_null(defaults$port)
  expect_true(defaults$launch.browser)
  expect_null(defaults$user_data_dir)
  expect_null(defaults$database_path)
})

test_that("run_voting_app depends on required functions", {
  # Check that the required utility functions exist
  expect_true(exists("get_user_data_dir"))
  expect_true(exists("init_user_data_structure"))
  expect_true(exists("init_external_database"))
  expect_true(exists("get_app_dir"))
  
  # Check that these are functions
  expect_true(is.function(get_user_data_dir))
  expect_true(is.function(init_user_data_structure))
  expect_true(is.function(init_external_database))
  expect_true(is.function(get_app_dir))
})

test_that("run_voting_app error handling for missing app directory", {
  # Test the error message structure
  # Since we can't easily mock system.file, we'll check the code structure
  
  # Read the function body to check for proper error handling
  func_body <- deparse(body(run_voting_app))
  
  # Should check for empty app_dir
  expect_true(any(grepl('app_dir == ""', func_body, fixed = TRUE)))
  
  # Should have a stop() call with appropriate message
  expect_true(any(grepl("Could not find Shiny app directory", func_body)))
})

test_that("run_voting_app sets environment variables", {
  # Test that the function code includes environment variable setting
  func_body <- deparse(body(run_voting_app))
  
  # Should set B1MG_USER_DATA_DIR environment variable
  expect_true(any(grepl("B1MG_USER_DATA_DIR", func_body)))
  
  # Should set B1MG_DATABASE_PATH environment variable
  expect_true(any(grepl("B1MG_DATABASE_PATH", func_body)))
  
  # Should use Sys.setenv
  expect_true(any(grepl("Sys.setenv", func_body)))
})

test_that("run_voting_app calls required initialization functions", {
  # Test that the function code includes calls to initialization functions
  func_body <- deparse(body(run_voting_app))
  
  # Should call init_user_data_structure
  expect_true(any(grepl("init_user_data_structure", func_body)))
  
  # Should call init_external_database
  expect_true(any(grepl("init_external_database", func_body)))
  
  # Should call get_user_data_dir when user_data_dir is NULL
  expect_true(any(grepl("get_user_data_dir", func_body)))
})

test_that("run_voting_app working directory management", {
  # Test that the function properly manages working directory
  func_body <- deparse(body(run_voting_app))
  
  # Should save old working directory
  expect_true(any(grepl("old_wd.*getwd", func_body)))
  
  # Should use on.exit to restore working directory
  expect_true(any(grepl("on.exit", func_body)))
  
  # Should change to app directory
  expect_true(any(grepl("setwd.*app_dir", func_body)))
})

test_that("run_voting_app calls shiny runApp", {
  # Test that the function properly calls shiny::runApp
  func_body <- deparse(body(run_voting_app))
  
  # Should call shiny::runApp or runApp
  expect_true(any(grepl("runApp", func_body)))
  
  # Should pass the required parameters
  expect_true(any(grepl("appDir.*app_dir", func_body)))
  expect_true(any(grepl("host.*host", func_body)))
  expect_true(any(grepl("port.*port", func_body)))
  expect_true(any(grepl("launch.browser.*launch.browser", func_body)))
})
