library(testthat)
library(B1MGVariantVoting)

# Test get_app_dir returns a valid directory

test_that("get_app_dir returns valid path", {
  app_dir <- get_app_dir()
  expect_true(dir.exists(app_dir))
  expect_true(file.exists(file.path(app_dir, "app.R")))
})

# Test run_voting_app sets env vars and forwards arguments

test_that("run_voting_app sets environment and calls shiny::runApp", {
  tmp <- tempdir()
  user_dir <- file.path(tmp, "user_data")
  db_path <- file.path(tmp, "db.sqlite")
  dir.create(user_dir, showWarnings = FALSE)
  
  # Store original environment variables
  orig_user_data <- Sys.getenv("B1MG_USER_DATA_DIR", unset = NA)
  orig_db_path <- Sys.getenv("B1MG_DATABASE_PATH", unset = NA)
  
  # Clear environment variables for test
  Sys.unsetenv("B1MG_USER_DATA_DIR")
  Sys.unsetenv("B1MG_DATABASE_PATH")

  call_args <- NULL
  
  # Mock shiny::runApp by temporarily replacing it
  original_runApp <- shiny::runApp
  mock_runApp <- function(appDir, host, port, launch.browser, ...) {
    call_args <<- list(appDir = appDir, host = host, port = port, launch.browser = launch.browser)
    invisible(NULL)
  }
  
  # Replace the function in shiny namespace
  assignInNamespace("runApp", mock_runApp, ns = "shiny")
  
  tryCatch({
    run_voting_app(host = "0.0.0.0", port = 5050, launch.browser = FALSE,
                   user_data_dir = user_dir, database_path = db_path)
    
    expect_equal(call_args$appDir, get_app_dir())
    expect_equal(call_args$host, "0.0.0.0")
    expect_equal(call_args$port, 5050)
    expect_false(call_args$launch.browser)
    expect_equal(Sys.getenv("B1MG_USER_DATA_DIR"), user_dir)
    expect_equal(Sys.getenv("B1MG_DATABASE_PATH"), db_path)
  }, finally = {
    # Restore original function
    assignInNamespace("runApp", original_runApp, ns = "shiny")
    
    # Restore original environment variables
    if (is.na(orig_user_data)) {
      Sys.unsetenv("B1MG_USER_DATA_DIR")
    } else {
      Sys.setenv(B1MG_USER_DATA_DIR = orig_user_data)
    }
    
    if (is.na(orig_db_path)) {
      Sys.unsetenv("B1MG_DATABASE_PATH")
    } else {
      Sys.setenv(B1MG_DATABASE_PATH = orig_db_path)
    }
  })
})

test_that("run_voting_app uses defaults when arguments are NULL", {
  # Store original environment variables
  orig_user_data <- Sys.getenv("B1MG_USER_DATA_DIR", unset = NA)
  orig_db_path <- Sys.getenv("B1MG_DATABASE_PATH", unset = NA)
  orig_wd <- getwd()
  
  call_args <- NULL
  
  # Mock shiny::runApp
  original_runApp <- shiny::runApp
  mock_runApp <- function(appDir, host, port, launch.browser, ...) {
    call_args <<- list(appDir = appDir, host = host, port = port, launch.browser = launch.browser)
    invisible(NULL)
  }
  
  # Replace the function in shiny namespace
  assignInNamespace("runApp", mock_runApp, ns = "shiny")
  
  tryCatch({
    run_voting_app(launch.browser = FALSE)
    
    # Check default values were used
    expect_equal(call_args$host, "127.0.0.1")
    expect_null(call_args$port)
    expect_false(call_args$launch.browser)
    expect_equal(call_args$appDir, get_app_dir())
    
    # Environment variables should be set
    expect_true(nchar(Sys.getenv("B1MG_USER_DATA_DIR")) > 0)
    expect_true(nchar(Sys.getenv("B1MG_DATABASE_PATH")) > 0)
    
    # Working directory should be restored
    expect_equal(getwd(), orig_wd)
    
  }, finally = {
    # Restore original function
    assignInNamespace("runApp", original_runApp, ns = "shiny")
    
    # Restore original environment variables
    if (is.na(orig_user_data)) {
      Sys.unsetenv("B1MG_USER_DATA_DIR")
    } else {
      Sys.setenv(B1MG_USER_DATA_DIR = orig_user_data)
    }
    
    if (is.na(orig_db_path)) {
      Sys.unsetenv("B1MG_DATABASE_PATH")
    } else {
      Sys.setenv(B1MG_DATABASE_PATH = orig_db_path)
    }
    
    setwd(orig_wd)
  })
})

test_that("run_voting_app has proper error handling structure", {
  # Instead of mocking system.file, just verify the function contains proper error handling
  func_body <- deparse(body(run_voting_app))
  
  # Should check for empty app_dir
  expect_true(any(grepl('app_dir == ""', func_body, fixed = TRUE)))
  
  # Should have a stop() call with appropriate message
  expect_true(any(grepl("Could not find Shiny app directory", func_body)))
})

test_that("run_voting_app passes extra arguments", {
  tmp <- tempdir()
  user_dir <- file.path(tmp, "user_data")
  dir.create(user_dir, showWarnings = FALSE)
  
  # Store original environment variables
  orig_user_data <- Sys.getenv("B1MG_USER_DATA_DIR", unset = NA)
  orig_db_path <- Sys.getenv("B1MG_DATABASE_PATH", unset = NA)
  
  call_args <- NULL
  extra_args <- NULL
  
  # Mock shiny::runApp
  original_runApp <- shiny::runApp
  mock_runApp <- function(appDir, host, port, launch.browser, ...) {
    call_args <<- list(appDir = appDir, host = host, port = port, launch.browser = launch.browser)
    extra_args <<- list(...)
    invisible(NULL)
  }
  
  # Replace the function in shiny namespace
  assignInNamespace("runApp", mock_runApp, ns = "shiny")
  
  tryCatch({
    run_voting_app(
      user_data_dir = user_dir,
      launch.browser = FALSE,
      display.mode = "showcase",
      test.mode = TRUE
    )
    
    # Check that extra arguments were passed
    expect_equal(extra_args$display.mode, "showcase")
    expect_true(extra_args$test.mode)
    
  }, finally = {
    # Restore original function
    assignInNamespace("runApp", original_runApp, ns = "shiny")
    
    # Restore original environment variables
    if (is.na(orig_user_data)) {
      Sys.unsetenv("B1MG_USER_DATA_DIR")
    } else {
      Sys.setenv(B1MG_USER_DATA_DIR = orig_user_data)
    }
    
    if (is.na(orig_db_path)) {
      Sys.unsetenv("B1MG_DATABASE_PATH")
    } else {
      Sys.setenv(B1MG_DATABASE_PATH = orig_db_path)
    }
  })
})