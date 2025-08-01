library(testthat)
library(ShinyImgVoteR)

# Test get_app_dir returns a valid directory

testthat::test_that("get_app_dir returns valid path", {
  app_dir <- get_app_dir()
  testthat::expect_true(dir.exists(app_dir))
  testthat::expect_true(file.exists(file.path(app_dir, "app.R")))
})


testthat::test_that("run_voting_app accepts calls shiny::runApp", {
  tmp <- tempdir()
  user_dir <- file.path(tmp, "user_data")
  db_path <- file.path(tmp, "db.sqlite")
  dir.create(user_dir, showWarnings = FALSE)

  # Sys.setenv(
  #   IMGVOTER_USER_DATA_DIR = user_dir,
  #   IMGVOTER_DATABASE_PATH = db_path
  # )

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
    
    testthat::expect_equal(call_args$appDir, get_app_dir())
    testthat::expect_equal(call_args$host, "0.0.0.0")
    testthat::expect_equal(call_args$port, 5050)
    expect_false(call_args$launch.browser)
  }, finally = {
    # Restore original function
    assignInNamespace("runApp", original_runApp, ns = "shiny")
  })
})

testthat::test_that("run_voting_app uses defaults when arguments are NULL", {
  # Store original environment variables
  orig_user_data <- Sys.getenv("IMGVOTER_USER_DATA_DIR", unset = NA)
  orig_db_path <- Sys.getenv("IMGVOTER_DATABASE_PATH", unset = NA)
  orig_wd <- getwd()
  
  call_args <- NULL
  
  # Mock shiny::runApp
  original_runApp <- shiny::runApp
  mock_runApp <- function(appDir, host, port, launch.browser, ...) {
    call_args <<- list(
      appDir = appDir, 
      host = host, 
      port = port, 
      launch.browser = launch.browser
    )
    invisible(NULL)
  }
  
  # Replace the function in shiny namespace
  assignInNamespace("runApp", mock_runApp, ns = "shiny")
  
  tryCatch({
    run_voting_app(launch.browser = FALSE)
    
    # Check default values were used
    testthat::expect_equal(call_args$host, "127.0.0.1")
    testthat::expect_equal(call_args$port, 8000)
    expect_false(call_args$launch.browser)
    testthat::expect_equal(call_args$appDir, get_app_dir())
    
    # Environment variables should be set
    testthat::expect_true(nchar(Sys.getenv("IMGVOTER_USER_DATA_DIR")) > 0)
    
    # Working directory should be restored
    testthat::expect_equal(getwd(), orig_wd)
    
  }, finally = {
    # Restore original function
    assignInNamespace("runApp", original_runApp, ns = "shiny")
    
    # Restore original environment variables
    if (is.na(orig_user_data)) {
      Sys.unsetenv("IMGVOTER_USER_DATA_DIR")
    } else {
      Sys.setenv(IMGVOTER_USER_DATA_DIR = orig_user_data)
    }
    
    if (is.na(orig_db_path)) {
      Sys.unsetenv("IMGVOTER_DATABASE_PATH")
    } else {
      Sys.setenv(IMGVOTER_DATABASE_PATH = orig_db_path)
    }
    # if db.sqlite in orig_wd, remove it
    db_file <- file.path(orig_wd, "db.sqlite")
    if (file.exists(db_file)) {
      unlink(db_file)
    }
    
    setwd(orig_wd)
  })
})

testthat::test_that("run_voting_app passes extra arguments", {
  tmp <- tempdir()
  user_dir <- file.path(tmp, "user_data")
  dir.create(user_dir, showWarnings = FALSE)
  
  # Store original environment variables
  orig_user_data <- Sys.getenv("IMGVOTER_USER_DATA_DIR", unset = NA)
  orig_db_path <- Sys.getenv("IMGVOTER_DATABASE_PATH", unset = NA)
  
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
    testthat::expect_equal(extra_args$display.mode, "showcase")
    testthat::expect_true(extra_args$test.mode)
    
  }, finally = {
    # Restore original function
    assignInNamespace("runApp", original_runApp, ns = "shiny")
    
    # Restore original environment variables
    if (is.na(orig_user_data)) {
      Sys.unsetenv("IMGVOTER_USER_DATA_DIR")
    } else {
      Sys.setenv(IMGVOTER_USER_DATA_DIR = orig_user_data)
    }
    
    if (is.na(orig_db_path)) {
      Sys.unsetenv("IMGVOTER_DATABASE_PATH")
    } else {
      Sys.setenv(IMGVOTER_DATABASE_PATH = orig_db_path)
    }
  })
})