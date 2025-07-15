library(testthat)
library(shiny)

library(ShinyImgVoteR)

# locate the directory where inst/shiny-app was installed
app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

# source your module(s)
# source(file.path(app_dir, "modules", "about_module.R"))


test_that("About module UI renders correctly", {
  ui_result <- aboutUI("test")
  expect_s3_class(ui_result, "shiny.tag.list")
  ui_html <- as.character(ui_result)
  expect_true(grepl("About this app", ui_html))
  expect_true(grepl("vote on somatic mutations", ui_html))
})


test_that("About server initializes without error", {
  expect_silent(
    testServer(aboutServer, {
      expect_true(TRUE)
    })
  )
})
