library(testthat)
library(shiny)
library(shinytest2)
library(B1MGVariantVoting)

# helper provides create_mock_db

app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")
source(file.path(app_dir, "config.R"))

# create mock database pool for db_pool expected by server()
mock_db <- create_mock_db()
db_pool <- mock_db$pool

# stub modules and logout server
loginServer <- function(id, db_conn, log_out) {
  list(
    login_data = reactiveVal(list(
      user_id = "test_user",
      voting_institute = "CNAG",
      session_id = "sess1"
    )),
    credentials = reactive(list(user_auth = TRUE)),
    update_logout_time = function(sessionid, conn = NULL) {
      assign("update_called", sessionid, envir = .GlobalEnv)
    }
  )
}

votingServer <- function(...) {}
leaderboardServer <- function(...) {}
userStatsServer <- function(...) {}
aboutServer <- function(...) {}

fake_logoutServer <- function(id, active) reactive(TRUE)
attach(list(logoutServer = fake_logoutServer), name = "shinyauthr")

source(file.path(app_dir, "server.R"))

teardown({
  pool::poolClose(mock_db$pool)
  unlink(mock_db$file)
  detach("package:shinyauthr")
})

test_that("user_stats_tab_trigger returns timestamp when tab selected", {
  my_session <- MockShinySession$new()
  testServer(server, session = my_session, {
    session$setInputs(main_navbar = "User stats")
    expect_s3_class(user_stats_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(user_stats_tab_trigger())
  })
})

test_that("leaderboard_tab_trigger returns timestamp when tab selected", {
  my_session <- MockShinySession$new()
  testServer(server, session = my_session, {
    session$setInputs(main_navbar = "Leaderboard")
    expect_s3_class(leaderboard_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(leaderboard_tab_trigger())
  })
})
