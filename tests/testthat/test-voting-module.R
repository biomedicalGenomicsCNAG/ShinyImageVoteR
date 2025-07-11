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

test_that("votingUI returns valid Shiny UI", {
  ui <- votingUI("test")
  expect_true(inherits(ui, "shiny.tag.list"))
})

test_that("voting module namespace works correctly", {
  ui <- votingUI("voting_module")
  # Check that namespaced IDs are present in the UI
  ui_html <- as.character(ui)
  expect_true(grepl("voting_module-agreement", ui_html))
  expect_true(grepl("voting_module-observation", ui_html))
  expect_true(grepl("voting_module-comment", ui_html))
})

# Test for UI elements structure
test_that("votingUI contains expected UI elements", {
  ui <- votingUI("test")
  ui_html <- as.character(ui)
  
  # Check for radio buttons
  expect_true(grepl("radioButtons", ui_html) || grepl('type="radio"', ui_html))
  
  # Check for action buttons
  expect_true(grepl("nextBtn", ui_html))
  expect_true(grepl("backBtn", ui_html))
  
  # Check for conditional panels
  expect_true(grepl("shiny-panel-conditional", ui_html))
})

test_that("hotkey configuration is consistent", {
  # Check that observation hotkeys match the number of observations
  expect_equal(length(observation_hotkeys), length(observations_dict))
  
  # Check that hotkeys are single characters
  expect_true(all(nchar(observation_hotkeys) == 1))
  
  # Check that hotkeys are unique
  expect_equal(length(observation_hotkeys), length(unique(observation_hotkeys)))
})
