library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(dplyr)
library(lubridate)

# Source the necessary files
source("../../config.R")
source("../../modules/user_stats_module.R")

test_that("User stats module UI renders correctly", {
  ui_result <- userStatsUI("test")
  expect_s3_class(ui_result, "shiny.tag")
  
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
      login_data = reactive({ list(user_id = "test", voting_institute = "CNAG") }),
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
  
  # Test with different trigger scenarios
  login_trigger <- reactiveVal(list(user_id = "test_user", voting_institute = "CNAG"))
  tab_trigger <- reactiveVal(NULL)
  
  testServer(userStatsServer, args = list(
    login_data = login_trigger,
    db_pool = pool,
    tab_trigger = tab_trigger
  ), {
    # Set up session userData
    session$userData <- list(
      userId = "test_user",
      votingInstitute = "CNAG",
      userAnnotationsFile = tempfile(fileext = ".tsv")
    )
    
    # Create empty annotations file
    write.table(
      data.frame(
        coordinates = character(0),
        agreement = character(0),
        alternative_vartype = character(0),
        observation = character(0),
        comment = character(0),
        shinyauthr_session_id = character(0),
        time_till_vote_casted_in_seconds = character(0)
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
