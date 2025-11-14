library(testthat)
library(shiny)

library(ShinyImgVoteR)

# locate the directory where inst/shiny-app was installed
app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

# source your module(s)
# source(file.path(app_dir, "modules", "about_module.R"))


testthat::test_that("About module UI renders correctly", {
  cfg <- ShinyImgVoteR::load_config(config_file_path = file.path(
    app_dir,
    "default_env",
    "config",
    "config.yaml"
  ))
  ui_result <- aboutUI("test", cfg)
  expect_s3_class(ui_result, "shiny.tag.list")
  ui_html <- as.character(ui_result)
  testthat::expect_true(grepl("About this app", ui_html))
  testthat::expect_true(grepl("vote on somatic mutations", ui_html))
})


testthat::test_that("About server initializes without error", {
  expect_silent(
    testServer(aboutServer, {
      testthat::expect_true(TRUE)
    })
  )
})
