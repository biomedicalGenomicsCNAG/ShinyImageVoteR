library(testthat)
library(shiny)
library(B1MGVariantVoting)

app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")
# source(file.path(app_dir, "server.R"))

test_that("user_stats_tab_trigger returns timestamp when tab selected", {
  mock_pool <- create_mock_db()$pool

  testServer(B1MGVariantVoting::makeVotingAppServer(mock_pool), {
    session$setInputs(main_navbar = "User stats")
    expect_s3_class(user_stats_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(user_stats_tab_trigger())
  })

  # cleanup
  poolClose(mock_pool)
})

test_that("leaderboard_tab_trigger returns timestamp when tab selected", {
  mock_pool <- create_mock_db()$pool

  testServer(B1MGVariantVoting::makeVotingAppServer(mock_pool), {
    session$setInputs(main_navbar = "Leaderboard")
    expect_s3_class(leaderboard_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(leaderboard_tab_trigger())
  })

  # cleanup
  poolClose(mock_pool)
})