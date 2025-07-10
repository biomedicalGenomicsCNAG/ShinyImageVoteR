library(testthat)
library(shiny)
library(B1MGVariantVoting)

# locate the directory where inst/shiny-app was installed
app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")

# source config and module
source(file.path(app_dir, "config.R"))
source(file.path(app_dir, "modules", "voting_module.R"))


test_that("color_seq colors nucleotides correctly", {
  seq <- "ACGT-"
  expected <- paste0(
    '<span style="color:', cfg_nt2color_map["A"], '">A</span>',
    '<span style="color:', cfg_nt2color_map["C"], '">C</span>',
    '<span style="color:', cfg_nt2color_map["G"], '">G</span>',
    '<span style="color:', cfg_nt2color_map["T"], '">T</span>',
    '<span style="color:', cfg_nt2color_map["-"], '">-</span>'
  )
  result <- color_seq(seq, cfg_nt2color_map)
  expect_equal(result, expected)
})
