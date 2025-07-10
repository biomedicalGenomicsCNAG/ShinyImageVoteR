library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(dplyr)
library(lubridate)
library(B1MGVariantVoting)

# locate the directory where inst/shiny-app was installed
app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")

# source necessary files
source(file.path(app_dir, "config.R"))
source(file.path(app_dir, "modules", "user_stats_module.R"))

test_that("User stats module UI renders correctly", {
  ui_result <- userStatsUI("test")
  expect_s3_class(ui_result, "shiny.tag.list")
  
  ui_html <- as.character(ui_result)
  expect_true(grepl("user_stats_table", ui_html))
  expect_true(grepl("refresh_user_stats", ui_html))
})

test_that("User stats server handles tab trigger parameter", {
  # Create a mock database pool
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create sessionids table
  dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Test that the function accepts the new tab_trigger parameter
  expect_silent({
    testServer(userStatsServer, args = list(
      login_trigger = reactive({ list(user_id = "test", voting_institute = "CNAG") }),
      db_pool = pool,
      tab_trigger = reactive({ Sys.time() })
    ), {
      # Basic test that the server function loads without error
      expect_true(TRUE)
    })
  })
  
  # Clean up
  poolClose(pool)
  unlink(db_file)
})

test_that("User stats reactive triggers correctly", {
  # Create a mock database pool
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create sessionids table
  dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Insert some test session data
  dbExecute(pool, "
    INSERT INTO sessionids (user, sessionid, login_time, logout_time)
    VALUES ('test_user', 'session123', '2023-01-01 10:00:00', '2023-01-01 10:30:00')
  ")
  
  # Test with different trigger scenarios
  login_trigger <- reactiveVal(list(user_id = "test_user", voting_institute = "CNAG"))
  tab_trigger <- reactiveVal(NULL)
  
  testServer(userStatsServer, args = list(
    login_trigger = login_trigger,
    db_pool = pool,
    tab_trigger = tab_trigger
  ), {
    # Set up session userData
    session$userData$userId <- "test_user"
    session$userData$votingInstitute <- "CNAG"
session$userData$userAnnotationsFile <- tempfile(fileext = ".tsv")
    
    # Create annotations file with some data
    write.table(
      data.frame(
        coordinates = c("chr1:1000", "chr2:2000"),
        agreement = c("yes", "no"),
        alternative_vartype = c("", ""),
        observation = c("", ""),
        comment = c("", ""),
        shinyauthr_session_id = c("session123", "session123"),
        time_till_vote_casted_in_seconds = c("5", "3"),
        stringsAsFactors = FALSE
      ),
      file = session$userData$userAnnotationsFile,
      sep = "\t",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE
    )
    
    # Test that reactive exists and can be triggered
    expect_true(is.reactive(stats))
    
    # Trigger tab change
    tab_trigger(Sys.time())
    
    # The stats should update (though they'll be empty due to test setup)
    result <- stats()
    expect_true(is.data.frame(result))
    
    # Clean up test file
    unlink(session$userData$userAnnotationsFile)
  })
  
  # Clean up
  poolClose(pool)
  unlink(db_file)
})

test_that("User stats server works without tab trigger (backward compatibility)", {
  # Create a mock database pool
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create sessionids table
  dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Test that the module still works when tab_trigger is not provided
  login_trigger <- reactiveVal(list(user_id = "test_user", voting_institute = "CNAG"))
  
  testServer(userStatsServer, args = list(
    login_trigger = login_trigger,
    db_pool = pool
    # Note: no tab_trigger parameter - testing backward compatibility
  ), {
    # Set up session userData
    session$userData$userId <- "test_user"
    session$userData$votingInstitute <- "CNAG"
    session$userData$userAnnotationsFile <- tempfile(fileext = ".tsv")
    
    # Create minimal annotations file
    write.table(
      data.frame(
        coordinates = "chr1:1000",
        agreement = "yes",
        alternative_vartype = "",
        observation = "",
        comment = "",
        shinyauthr_session_id = "session123",
        time_till_vote_casted_in_seconds = "5",
        stringsAsFactors = FALSE
      ),
      file = session$userData$userAnnotationsFile,
      sep = "\t",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE
    )
    
    # Test that reactive exists and works without tab trigger
    expect_true(is.reactive(stats))
    
    # The stats should work even without tab trigger
    result <- stats()
    expect_true(is.data.frame(result))
    
    # Clean up test file
    unlink(session$userData$userAnnotationsFile)
  })
  
  # Clean up
  poolClose(pool)
  unlink(db_file)
})
