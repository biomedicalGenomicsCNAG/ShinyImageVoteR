library(testthat)
library(shiny)
library(pool)
library(RSQLite)
library(DBI)

# locate the directory where inst/shiny-app was installed
app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")

# helper to source in isolated env with correct working directory
source_app <- function(file, env) {
  old_wd <- getwd()
  on.exit(setwd(old_wd))
  setwd(app_dir)
  source(file, local = env)
}

test_that("all modules are loaded into the global environment", {
  env <- new.env()
  source_app("config.R", env)
  source_app("global.R", env)
  
  # Check for module UI functions
  ui_functions <- c("loginUI", "votingUI", "leaderboardUI", "userStatsUI", "aboutUI")
  for (f in ui_functions) {
    expect_true(exists(f, envir = env),
                info = paste(f, "should be available after sourcing global.R"))
    expect_true(is.function(get(f, envir = env)),
                info = paste(f, "should be a function"))
  }
  
  # Check for module Server functions
  server_functions <- c("loginServer", "votingServer", "leaderboardServer", "userStatsServer", "aboutServer")
  for (f in server_functions) {
    expect_true(exists(f, envir = env),
                info = paste(f, "should be available after sourcing global.R"))
    expect_true(is.function(get(f, envir = env)),
                info = paste(f, "should be a function"))
  }
})
