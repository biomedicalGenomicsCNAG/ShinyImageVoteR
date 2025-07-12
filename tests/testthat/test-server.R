library(testthat)
library(shiny)
library(B1MGVariantVoting)

test_that("user_stats_tab_trigger returns timestamp when tab selected", {
  testServer(server, {
    session$setInputs(main_navbar = "User stats")
    expect_s3_class(user_stats_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    # expect_null(user_stats_tab_trigger())
  })
})