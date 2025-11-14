library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(dplyr)
library(lubridate)
library(ShinyImgVoteR)

# locate the directory where inst/shiny-app was installed
# app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

# # source necessary files
# source(file.path(app_dir, "config.R"))
# source(file.path(app_dir, "modules", "user_stats_module.R"))

testthat::test_that("User stats module UI renders correctly", {
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )

  ui_result <- userstatsUI("test", cfg)
  expect_s3_class(ui_result, "shiny.tag.list")
  
  ui_html <- as.character(ui_result)
  testthat::expect_true(grepl("user_stats_table", ui_html))
  testthat::expect_true(grepl("refresh_user_stats", ui_html))
})

testthat::test_that("User stats server handles tab trigger parameter", {
  # Create a mock database pool
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create sessionids table
  DBI::dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  
  # Test that the function accepts the new tab_trigger parameter
  expect_silent({
    testServer(userStatsServer, args = list(
      cfg,
      login_trigger = reactive({list(user_id = "test", voting_institute = "CNAG") }),
      db_pool = pool,
      tab_trigger = reactive({ Sys.time() })
    ), {
      # Basic test that the server function loads without error
      testthat::expect_true(TRUE)
    })
  })
  
  # Clean up
  poolClose(pool)
  unlink(db_file)
})

testthat::test_that("User stats reactive triggers correctly", {
  # Create a mock database pool
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create sessionids table
  DBI::dbExecute(pool, "
    CREATE TABLE sessionids (
      userid TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Insert some test session data
  DBI::dbExecute(pool, "
    INSERT INTO sessionids (userid, sessionid, login_time, logout_time)
    VALUES ('test_user', 'session123', '2023-01-01 10:00:00', '2023-01-01 10:30:00')
  ")
  
  # Test with different trigger scenarios
  login_trigger <- shiny::reactiveVal(list(user_id = "test_user", voting_institute = "CNAG"))
  tab_trigger <- shiny::reactiveVal(NULL)
  
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  testServer(userStatsServer, args = list(
    cfg,
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
    testthat::expect_true(is.reactive(stats))
    
    # Trigger tab change
    tab_trigger(Sys.time())
    
    # The stats should update (though they'll be empty due to test setup)
    result <- stats()
    testthat::expect_true(is.data.frame(result))
    
    # Clean up test file
    unlink(session$userData$userAnnotationsFile)
  })
  
  # Clean up
  poolClose(pool)
  unlink(db_file)
})

testthat::test_that("User stats server works without tab trigger (backward compatibility)", {
  # Create a mock database pool
  db_file <- tempfile(fileext = ".sqlite")
  pool <- dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create sessionids table
  DBI::dbExecute(pool, "
    CREATE TABLE sessionids (
      userid TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Test that the module still works when tab_trigger is not provided
  login_trigger <- reactiveVal(list(user_id = "test_user", voting_institute = "CNAG"))
  
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  testServer(userStatsServer, args = list(
    cfg,
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
    testthat::expect_true(is.reactive(stats))
    
    # The stats should work even without tab trigger
    result <- stats()
    testthat::expect_true(is.data.frame(result))
    
    # Clean up test file
    unlink(session$userData$userAnnotationsFile)
  })
  
  # Clean up
  poolClose(pool)
  unlink(db_file)
})
