library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(B1MGVariantVoting)

# locate the directory where inst/shiny-app was installed
app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")

# source config and module
source(file.path(app_dir, "config.R"))
source(file.path(app_dir, "server.R"))
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

# Test: module can be invoked
test_that("votingServer can be called within testServer", {
  env <- setup_voting_env(c("chr1:100"))
  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg_test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # If we reach here without error, the module initialized successfully
      expect_true(TRUE)
    }
  )
})

test_that("votingServer handles different agreement types", {
  env <- setup_voting_env(c("chr1:100"))
  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg_test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # Just test that inputs can be set without triggering nextBtn
      # Test 'yes' agreement
      session$setInputs(agreement = "yes")
      expect_equal(input$agreement, "yes")

      # Test 'no' agreement
      session$setInputs(agreement = "no")
      expect_equal(input$agreement, "no")

      # Test 'not_confident' agreement
      session$setInputs(agreement = "not_confident")
      expect_equal(input$agreement, "not_confident")
      
      expect_true(TRUE)  # If we reach here, it worked
    }
  )
})

test_that("votingServer handles comment and observation inputs", {
  env <- setup_voting_env(c("chr1:100"))
  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg_test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # Set inputs for comment and observation
      session$setInputs(comment = "Test comment")
      session$setInputs(observation = "Test observation")

      # Verify that inputs were set correctly
      expect_equal(input$comment, "Test comment")
      expect_equal(input$observation, "Test observation")
    }
  )
})

# Test: module reacts to nextBtn click
test_that("votingServer responds to nextBtn click", {
  env <- setup_voting_env(c("chr1:100"))
  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg_test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # Simulate user selecting 'yes' and clicking 'Next'
      session$setInputs(agreement = "yes")
      session$setInputs(nextBtn = 1)

      # Verify behavior: here just ensure no errors
      expect_true(TRUE)
    }
  )
})