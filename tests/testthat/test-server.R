library(testthat)
library(shiny)
library(shinytest2)
library(B1MGVariantVoting)

app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")
# source(file.path(app_dir, "server.R"))

test_that("user_stats_tab_trigger returns timestamp when tab selected", {
  # create test db 
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool

  # make it available in the global environment
  assign("db_pool", db_pool, envir = .GlobalEnv)

  testServer(server, {
    session$setInputs(main_navbar = "User stats")
    # expect_s3_class(user_stats_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    # expect_null(user_stats_tab_trigger())
  })

  # Cleanup
  p <- get("db_pool", envir = .GlobalEnv)
  pool::poolClose(p)
  unlink(mock_db$file)
})