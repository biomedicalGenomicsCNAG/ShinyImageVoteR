# tests/testthat/test_global.R
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

test_that("global.R sources without error and defines db_pool", {
  skip_if_not(dir.exists(app_dir), "app directory not found")
  env <- new.env()
  # source config first
  source_app("config.R", env)
  # then global
  expect_error(source_app("global.R", env), NA)
  expect_true(exists("db_pool", envir = env), "db_pool should be created")

  p <- get("db_pool", envir = env)
  poolClose(p)
})

test_that("db_pool is a working Pool object", {
  skip_if_not(dir.exists(app_dir), "app directory not found")
  env <- new.env()
  source_app("config.R", env)
  source_app("global.R", env)
  
  p <- get("db_pool", envir = env)
  expect_s3_class(p, "Pool")
  # simple query
  res <- dbGetQuery(p, "SELECT 1 AS one;")
  expect_equal(res$one, 1)
  
  p <- get("db_pool", envir = env)
  poolClose(p)
})

test_that("all modules are loaded into the global environment", {
  skip_if_not(dir.exists(app_dir), "app directory not found")
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
  
  # cleanup
  p <- get("db_pool", envir = env)
  poolClose(p)
})

test_that("cfg_sqlite_file points to an existing SQLite file", {
  skip_if_not(dir.exists(app_dir), "app directory not found")
  env <- new.env()
  source_app("config.R", env)
  expect_true(file.exists(env$cfg_sqlite_file),
              info = "cfg_sqlite_file must refer to an existing .sqlite file")
})
