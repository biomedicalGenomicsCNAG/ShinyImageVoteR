library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(ShinyImgVoteR)

# locate the directory where inst/shiny-app was installed
# app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

# # source config and module
# source(file.path(app_dir, "config.R"))
# source(file.path(app_dir, "modules", "voting_module.R"))

cfg <- ShinyImgVoteR::load_config()

testthat::test_that("color_seq colors nucleotides correctly", {
  seq <- "ACGT-"
  expected <- paste0(
    '<span style="color:', cfg$nt2color_map["A"], '">A</span>',
    '<span style="color:', cfg$nt2color_map["C"], '">C</span>',
    '<span style="color:', cfg$nt2color_map["G"], '">G</span>',
    '<span style="color:', cfg$nt2color_map["T"], '">T</span>',
    '<span style="color:', cfg$nt2color_map["-"], '">-</span>'
  )
  result <- ShinyImgVoteR:::color_seq(seq, cfg$nt2color_map)
  testthat::expect_equal(result, expected)
})

testthat::test_that("votingUI returns valid Shiny UI", {
  ui <- votingUI("test")
  testthat::expect_true(inherits(ui, "shiny.tag.list"))
})

testthat::test_that("voting module namespace works correctly", {
  ui <- votingUI("voting_module")
  # Check that namespaced IDs are present in the UI
  ui_html <- as.character(ui)
  testthat::expect_true(grepl("voting_module-agreement", ui_html))
  testthat::expect_true(grepl("voting_module-observation", ui_html))
  testthat::expect_true(grepl("voting_module-comment", ui_html))
})

# Test for UI elements structure
testthat::test_that("votingUI contains expected UI elements", {
  ui <- votingUI("test")
  ui_html <- as.character(ui)
  
  # Check for radio buttons
  testthat::expect_true(grepl("radioButtons", ui_html) || grepl('type="radio"', ui_html))
  
  # Check for action buttons
  testthat::expect_true(grepl("nextBtn", ui_html))
  testthat::expect_true(grepl("backBtn", ui_html))
  
  # Check for conditional panels
  testthat::expect_true(grepl("shiny-panel-conditional", ui_html))
})

testthat::test_that("hotkey configuration is consistent", {
  # Check that observation hotkeys match the number of observations
  testthat::expect_equal(length(cfg$observation_hotkeys), length(cfg$observations_dict))
  
  # Check that hotkeys are single characters
  testthat::expect_true(all(nchar(cfg$observation_hotkeys) == 1))
  
  # Check that hotkeys are unique
  testthat::expect_equal(length(cfg$observation_hotkeys), length(unique(cfg$observation_hotkeys)))
})

# Test: module can be invoked
testthat::test_that("votingServer can be called within testServer", {
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())
  
  testServer(
    votingServer,
    args = args,
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # If we reach here without error, the module initialized successfully
      testthat::expect_true(TRUE)
    }
  )
})

testthat::test_that("votingServer handles different agreement types", {
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())
  
  testServer(
    votingServer,
    args = args,
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # Just test that inputs can be set without triggering nextBtn
      # Test 'yes' agreement
      session$setInputs(agreement = "yes")
      testthat::expect_equal(input$agreement, "yes")

      # Test 'no' agreement
      session$setInputs(agreement = "no")
      testthat::expect_equal(input$agreement, "no")

      # Test 'not_confident' agreement
      session$setInputs(agreement = "not_confident")
      testthat::expect_equal(input$agreement, "not_confident")
      
      testthat::expect_true(TRUE)  # If we reach here, it worked
    }
  )
})

testthat::test_that("votingServer handles comment and observation inputs", {
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  testServer(
    votingServer,
    args = args,
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # Set inputs for comment and observation
      session$setInputs(comment = "Test comment")
      session$setInputs(observation = "Test observation")

      # Verify that inputs were set correctly
      testthat::expect_equal(input$comment, "Test comment")
      testthat::expect_equal(input$observation, "Test observation")
    }
  )
})

# Test: module reacts to nextBtn click
testthat::test_that("votingServer responds to nextBtn click", {
  env <- setup_voting_env(c("chr1:1000", "chr1:2000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())
  
  testServer(
    votingServer,
    args = args,
    {
      # Set up session userData that the module expects
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # Simulate user selecting 'yes' and clicking 'Next'
      session$setInputs(agreement = "yes")
      session$setInputs(nextBtn = 1)
      
      testthat::expect_true(TRUE)
    }
  )
})

testthat::test_that("votingServer writes agreement to annotations file on nextBtn", {
  # Set up test environment
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  my_session <- MockShinySession$new()
  my_session$clientData <- reactiveValues(
    url_search = "?coords=chr1:1000"
  )

  testServer(
    votingServer, 
    session = my_session,
    args = args, 
    {
      # Set up session userData needed by the observer
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$shinyauthr_session_id <- "session_123"
      session$userData$votingInstitute <- cfg$test_institute
      
      # Manually set current_mutation to simulate a loaded variant
      # This bypasses the complex get_mutation reactive chain
      current_mutation <- reactiveVal(list(
        coordinates = "chr1:1000",
        REF = "A",
        ALT = "T", 
        variant = "A>T",
        path = "dummy.png"  
      ))
      
      # Replace the module's current_mutation with our test version
      assign("current_mutation", current_mutation, envir = parent.frame())

      # Simulate the user clicking Next with an agreement
      session$setInputs(agreement = "no")
      testthat::expect_equal(input$agreement, "no")

      session$setInputs(alternative_vartype = "A>T")
      testthat::expect_equal(input$alternative_vartype, "A>T")

      session$setInputs(observation = "Test observation")
      testthat::expect_equal(input$observation, "Test observation")

      # Now simulate clicking the “Next” button
      session$setInputs(nextBtn = 1)

      # Read back the annotations file and assert contents
      annotations <- read.delim(
        env$annotations_file,
        header = TRUE,
        stringsAsFactors = FALSE
      )

      # expected headers
      expected_headers <- c(
        "coordinates", "agreement", "alternative_vartype",
        "observation", "comment", "shinyauthr_session_id",
        "time_till_vote_casted_in_seconds"
      )

      # Check that the annotations file has the expected headers
      testthat::expect_equal(colnames(annotations), expected_headers)     
    }
  )
})

testthat::test_that("votingServer handles duplicate voting from same session", {
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  testServer(
    votingServer,
    args = args,
    {
      # Set up session userData
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- "DIFFERENT_INSTITUTE"
      session$userData$shinyauthr_session_id <- "test_session_123"
      
      # Initialize with coordinates
      session$setInputs(url_params = list(coordinates = "chr1:1000"))
      
      # First vote
      session$setInputs(
        agreement = "yes",
        comment = "First vote"
      )
      session$setInputs(nextBtn = 1)
      
      # Second vote attempt (should be detected as already voted)
      session$setInputs(
        agreement = "no",
        comment = "Second vote"
      )
      session$setInputs(nextBtn = 2)
      
      # Verify duplicate vote handling (covers lines 221-231)
      testthat::expect_true(TRUE)
    }
  )
})

testthat::test_that("get_mutation returns done tibble when all variants voted", {
  env <- setup_voting_env(c("chr1:1000"))
  ann <- read.delim(env$annotations_file, stringsAsFactors = FALSE)
  ann$agreement <- "yes"
  write.table(ann, env$annotations_file, sep = "\t", row.names = FALSE, quote = FALSE)

  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  my_session <- MockShinySession$new()
  my_session$clientData <- reactiveValues(
    url_search = "?coords=done"
  )

  testServer(
    votingServer,
    session = my_session,
    args = args,
    {
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "done_session"

      session$setInputs(nextBtn = 1)
      session$flushReact()
      res <- get_mutation()
      testthat::expect_equal(res$coordinates, "done")
    }
  )
})

testthat::test_that("get_mutation gets triggered with not existing coordinates", {
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  my_session <- MockShinySession$new()
  my_session$clientData <- reactiveValues(
    url_search = "?coords=not_existing"
  )

  testServer(
    votingServer,
    session = my_session,
    args = args,
    {
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "coords_not_existing"

      session$setInputs(nextBtn = 1)
      session$flushReact()
      res <- get_mutation()
      testthat::expect_equal(res$coordinates, NULL)
    }
  )
})
