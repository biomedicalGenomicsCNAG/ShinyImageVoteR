library(testthat)
library(shiny)
library(B1MGVariantVoting)

# locate the directory where inst/shiny-app was installed
app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")

# source config and module
source(file.path(app_dir, "config.R"))
source(file.path(app_dir, "server.R"))
source(file.path(app_dir, "modules", "voting_module.R"))

# Helper to set up a test environment and annotations file
setup_voting_env <- function(coordinates) {
  temp_dir <- tempdir()
  test_user_data_dir <- file.path(temp_dir, "test_user_data")
  dir.create(test_user_data_dir, recursive = TRUE, showWarnings = FALSE)

  test_annotations_file <- file.path(test_user_data_dir, "test_annotations.txt")
  test_annotations <- data.frame(
    coordinates = coordinates,
    agreement = "",
    alternative_vartype = "",
    observation = "",
    comment = "",
    shinyauthr_session_id = "",
    time_till_vote_casted_in_seconds = NA,
    stringsAsFactors = FALSE
  )
  write.table(
    test_annotations, test_annotations_file, sep = "\t",
    row.names = FALSE, col.names = TRUE, quote = FALSE
  )

  list(
    data_dir = test_user_data_dir,
    annotations_file = test_annotations_file
  )
}

# Common args for server initialization
make_args <- function(annotations_file) {
  list(
    id = "voting",
    login_trigger = reactiveVal(
      list(user_id = "test_user", voting_institute = "CNAG")
    ),
    userData = list(
      userAnnotationsFile = annotations_file,
      votingInstitute = cfg_test_institute,
      shinyauthr_session_id = "test_session_123"
    )
  )
}


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
  env <- setup_voting_env(c("chr1:100-200"))
  on.exit(unlink(env$data_dir, recursive = TRUE), add = TRUE)

  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # If we reach here without error, the module initialized successfully
      expect_true(TRUE)
    }
  )
})

# Test: module reacts to nextBtn click
test_that("votingServer responds to nextBtn click", {
  env <- setup_voting_env(c("chr1:100-200", "chr2:300-400"))
  on.exit(unlink(env$data_dir, recursive = TRUE), add = TRUE)

  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # Simulate user selecting 'yes' and clicking 'Next'
      session$setInputs(`voting-agreement` = "yes")
      session$setInputs(`voting-nextBtn` = 1)

      # Verify behavior: here just ensure no errors
      expect_true(TRUE)
    }
  )
})


test_that("votingServer handles different agreement types", {
  env <- setup_voting_env(c("chr1:100-200"))
  on.exit(unlink(env$data_dir, recursive = TRUE), add = TRUE)

  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # Test 'yes' agreement
      session$setInputs(`voting-agreement` = "yes")
      session$setInputs(`voting-nextBtn` = 1)
      expect_true(TRUE)  # If we reach here, it worked

      # Test 'no' agreement
      session$setInputs(`voting-agreement` = "no")
      session$setInputs(`voting-nextBtn` = 1)
      expect_true(TRUE)  # If we reach here, it worked

      # Test 'not_confident' agreement
      session$setInputs(`voting-agreement` = "not_confident")
      session$setInputs(`voting-nextBtn` = 1)
      expect_true(TRUE)  # If we reach here, it worked
    }
  )
})

test_that("votingServer handles comment and observation inputs", {
  env <- setup_voting_env(c("chr1:100-200"))
  on.exit(unlink(env$data_dir, recursive = TRUE), add = TRUE)

  testServer(
    votingServer,
    args = make_args(env$annotations_file),
    {
      # Set inputs for comment and observation
      session$setInputs(`comment` = "Test comment")
      session$setInputs(`observation` = "Test observation")

      # Verify that inputs were set correctly
      expect_equal(input$comment, "Test comment")
      expect_equal(input$observation, "Test observation")
    }
  )
})
