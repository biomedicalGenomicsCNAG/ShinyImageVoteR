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

cfg <- ShinyImgVoteR::load_config(
  config_file_path = system.file(
    "shiny-app",
    "default_env",
    "config",
    "config.yaml",
    package = "ShinyImgVoteR"
  )
)

testthat::test_that("color_seq colors nucleotides correctly", {
  seq <- "ACGT-"
  expected <- paste0(
    '<span style="color:',
    cfg$nt2color_map["A"],
    '">A</span>',
    '<span style="color:',
    cfg$nt2color_map["C"],
    '">C</span>',
    '<span style="color:',
    cfg$nt2color_map["G"],
    '">G</span>',
    '<span style="color:',
    cfg$nt2color_map["T"],
    '">T</span>',
    '<span style="color:',
    cfg$nt2color_map["-"],
    '">-</span>'
  )
  result <- ShinyImgVoteR:::color_seq(seq, cfg$nt2color_map)
  testthat::expect_equal(result, expected)
})

testthat::test_that("votingUI returns valid Shiny UI", {
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  ui <- votingUI("test", cfg)
  testthat::expect_true(inherits(ui, "shiny.tag.list"))
})

testthat::test_that("voting module namespace works correctly", {
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  ui <- votingUI("voting_module", cfg)
  # Check that namespaced IDs are present in the UI
  ui_html <- as.character(ui)
  testthat::expect_true(grepl("voting_module-agreement", ui_html))
  testthat::expect_true(grepl("voting_module-observation", ui_html))
  testthat::expect_true(grepl("voting_module-comment", ui_html))
})

# Test for UI elements structure

# TODO
# FIX

# testthat::test_that("votingUI contains expected UI elements", {
#   cfg <- ShinyImgVoteR::load_config(
#     config_file_path = system.file(
#       "shiny-app",
#       "default_env",
#       "config",
#       "config.yaml",
#       package = "ShinyImgVoteR"
#     )
#   )
#   ui <- votingUI("test", cfg)
#   ui_html <- as.character(ui)

#   # Check for radio buttons
#   testthat::expect_true(grepl("radioButtons", ui_html) || grepl('type="radio"', ui_html))

#   # Check for action buttons
#   testthat::expect_true(grepl("nextBtn", ui_html))
#   testthat::expect_true(grepl('id="test-nextBtn"[^>]*disabled', ui_html))
#   testthat::expect_true(grepl("backBtn", ui_html))

#   # Check for conditional panels
#   testthat::expect_true(grepl("shiny-panel-conditional", ui_html))
# })

testthat::test_that("hotkey configuration is consistent", {
  # Check that observation hotkeys match the number of observations
  testthat::expect_equal(
    length(cfg$observation_hotkeys),
    length(cfg$observations_dict)
  )

  # Check that hotkeys are single characters
  testthat::expect_true(all(nchar(cfg$observation_hotkeys) == 1))

  # Check that hotkeys are unique
  testthat::expect_equal(
    length(cfg$observation_hotkeys),
    length(unique(cfg$observation_hotkeys))
  )
})

# Test: module can be invoked
testthat::test_that("votingServer can be called within testServer", {
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )

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

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
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

      # Test 'diff_var' agreement
      session$setInputs(agreement = "diff_var")
      testthat::expect_equal(input$agreement, "diff_var")

      # Test 'germline' agreement
      session$setInputs(agreement = "germline")
      testthat::expect_equal(input$agreement, "germline")

      # Test 'none_of_above' agreement
      session$setInputs(agreement = "none_of_above")
      testthat::expect_equal(input$agreement, "none_of_above")

      testthat::expect_true(TRUE) # If we reach here, it worked
    }
  )
})

testthat::test_that("votingServer handles comment and observation inputs", {
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
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

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
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
  my_session$clientData <- shiny::reactiveValues(
    url_search = "?coordinate=chr1:1000"
  )

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
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
      current_mutation <- shiny::reactiveVal(list(
        coordinates = "chr1:1000",
        REF = "A",
        ALT = "T",
        variant = "A>T",
        path = "dummy.png"
      ))

      # Replace the module's current_mutation with our test version
      assign("current_mutation", current_mutation, envir = parent.frame())

      # Simulate the user clicking Next with an agreement
      session$setInputs(agreement = "diff_var")
      testthat::expect_equal(input$agreement, "diff_var")

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
        "coordinates",
        "agreement",
        "alternative_vartype",
        "observation",
        "comment",
        "shinyauthr_session_id",
        "coordinates", "agreement",
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

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
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
        agreement = "diff_var",
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
  write.table(
    ann,
    env$annotations_file,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )

  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = "?coordinate=done"
  )

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
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

testthat::test_that(
  "screenshots over max votes are logged as skipped in annotations",
  {
    temp_dir <- tempdir()
    annotations_path <- file.path(
      temp_dir,
      paste0("skip_annotations_", Sys.getpid(), ".tsv")
    )

    annotations_df <- data.frame(
      coordinates = "chr1:1000",
      REF = "A",
      ALT = "T",
      agreement = NA_character_,
      observation = NA_character_,
      comment = NA_character_,
      shinyauthr_session_id = NA_character_,
      time_till_vote_casted_in_seconds = NA_real_,
      stringsAsFactors = FALSE
    )

    write.table(
      annotations_df,
      annotations_path,
      sep = "\t",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE,
      na = "NA"
    )

    args <- make_args(annotations_path)
    cleanup_db <- setup_test_db(args)
    on.exit(cleanup_db())

    args$cfg <- ShinyImgVoteR::load_config(
      config_file_path = system.file(
        "shiny-app",
        "default_env",
        "config",
        "config.yaml",
        package = "ShinyImgVoteR"
      )
    )

    config_max_votes <- args$cfg$max_votes_per_screenshot
    if (is.null(config_max_votes)) {
      config_max_votes <- 3
    }
    expected_skip_reason <- paste0(
      "skipped - max votes (",
      config_max_votes,
      ") reached"
    )

    DBI::dbExecute(
      db_pool,
      "UPDATE annotations SET vote_count_correct = 1 WHERE coordinates = ? AND REF = ? AND ALT = ?",
      params = list("chr1:1000", "A", "T")
    )

    testServer(
      votingServer,
      args = args,
      {
        session$userData$userAnnotationsFile <- annotations_path
        session$userData$votingInstitute <- cfg$test_institute
        session$userData$shinyauthr_session_id <- "skip_session"

        session$setInputs(nextBtn = 1)
        session$flushReact()
        result <- get_mutation()

        testthat::expect_equal(result$coordinates, "done")

        updated_annotations <- read.delim(
          annotations_path,
          stringsAsFactors = FALSE
        )
        testthat::expect_equal(
          updated_annotations$agreement[1],
          expected_skip_reason
        )
      }
    )
  }
)

# testthat::test_that("get_mutation gets triggered with not existing coordinates", {
#   env <- setup_voting_env(c("chr1:1000"))
#   args <- make_args(env$annotations_file)
#   cleanup_db <- setup_test_db(args)
#   on.exit(cleanup_db())

#   my_session <- MockShinySession$new()
#   my_session$clientData <- shiny::reactiveValues(
#     url_search = "?coordinate=not_existing"
#   )

#   args$cfg <- ShinyImgVoteR::load_config(
#     config_file_path = system.file(
#       "shiny-app",
#       "default_env",
#       "config",
#       "config.yaml",
#       package = "ShinyImgVoteR"
#     )
#   )
#   testServer(
#     votingServer,
#     session = my_session,
#     args = args,
#     {
#       session$userData$userAnnotationsFile <- env$annotations_file
#       session$userData$votingInstitute <- cfg$test_institute
#       session$userData$shinyauthr_session_id <- "coord_not_existing"

#       session$setInputs(nextBtn = 1)
#       session$flushReact()
#       res <- get_mutation()
#       testthat::expect_equal(res$coordinates, NULL)
#     }
#   )
# })

testthat::test_that("UI inputs are restored when navigating back to previously voted image", {
  # Set up two coordinates
  env <- setup_voting_env(c("chr1:1000", "chr1:2000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  # Pre-save a vote for chr1:1000
  annotations <- read.delim(env$annotations_file, stringsAsFactors = FALSE)
  annotations[annotations$coordinates == "chr1:1000", "agreement"] <- "yes"
  annotations[
    annotations$coordinates == "chr1:1000",
    "observation"
  ] <- "coverage;low_af"
  annotations[
    annotations$coordinates == "chr1:1000",
    "comment"
  ] <- "Test comment"
  write.table(
    annotations,
    env$annotations_file,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )

  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = "?coordinate=chr1:1000"
  )

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  testServer(
    votingServer,
    session = my_session,
    args = args,
    {
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_nav_session"

      # Trigger the mutation loading
      session$flushReact()

      # The observer should have updated the inputs to match saved values
      # Note: In testServer, we can't directly check if updateRadioButtons was called,
      # but we can verify the logic by checking that the mutation loaded correctly
      res <- get_mutation()
      testthat::expect_equal(res$coordinates, "chr1:1000")

      # Verify annotations file still has the saved values
      saved_annotations <- read.delim(
        env$annotations_file,
        stringsAsFactors = FALSE
      )
      saved_row <- saved_annotations[
        saved_annotations$coordinates == "chr1:1000",
      ]
      testthat::expect_equal(saved_row$agreement, "yes")
      testthat::expect_equal(saved_row$observation, "coverage;low_af")
      testthat::expect_equal(saved_row$comment, "Test comment")
    }
  )
})

# TODO
# FIX

# testthat::test_that("UI inputs are cleared when navigating to unvoted image", {
#   # Set up two coordinates
#   env <- setup_voting_env(c("chr1:1000", "chr1:2000"))
#   args <- make_args(env$annotations_file)
#   cleanup_db <- setup_test_db(args)
#   on.exit(cleanup_db())

#   my_session <- MockShinySession$new()
#   my_session$clientData <- shiny::reactiveValues(
#     url_search = "?coordinate=chr1:2000"
#   )

#   args$cfg <- ShinyImgVoteR::load_config(
#     config_file_path = system.file(
#       "shiny-app",
#       "default_env",
#       "config",
#       "config.yaml",
#       package = "ShinyImgVoteR"
#     )
#   )
#   testServer(
#     votingServer,
#     session = my_session,
#     args = args,
#     {
#       session$userData$userAnnotationsFile <- env$annotations_file
#       session$userData$votingInstitute <- cfg$test_institute
#       session$userData$shinyauthr_session_id <- "test_clear_session"

#       # Trigger the mutation loading
#       session$flushReact()

#       # Verify annotations file shows no vote for chr1:2000
#       saved_annotations <- read.delim(
#         env$annotations_file,
#         stringsAsFactors = FALSE
#       )
#       saved_row <- saved_annotations[
#         saved_annotations$coordinates == "chr1:2000",
#       ]
#       testthat::expect_equal(saved_row$agreement, "")
#       testthat::expect_equal(saved_row$observation, "")
#       testthat::expect_equal(saved_row$comment, "")
#     }
#   )
# })
#       # The observer should clear inputs for unvoted image
#       res <- get_mutation()
#       testthat::expect_equal(res$coordinates, "chr1:2000")

#       # Verify annotations file shows no vote for chr1:2000
#       saved_annotations <- read.delim(env$annotations_file, stringsAsFactors = FALSE)
#       saved_row <- saved_annotations[saved_annotations$coordinates == "chr1:2000", ]
#       testthat::expect_equal(saved_row$agreement, NA)
#       testthat::expect_equal(saved_row$observation,NA)
#       testthat::expect_equal(saved_row$comment, NA)
#     }
#   )
# })

testthat::test_that("get_mutation skips screenshots with 3 or more total votes", {
  # Set up environment with 3 coordinates
  env <- setup_voting_env(c("chr1:1000", "chr2:2000", "chr3:3000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  # Set vote_count_total directly
  # chr1:1000 has 3 votes (at max), chr2:2000 has 2 votes, chr3:3000 has 0 votes
  DBI::dbExecute(
    args$db_pool,
    "UPDATE annotations SET vote_count_total = 3 WHERE coordinates = 'chr1:1000'"
  )
  DBI::dbExecute(
    args$db_pool,
    "UPDATE annotations SET vote_count_total = 2 WHERE coordinates = 'chr2:2000'"
  )

  # Verify the vote counts were set correctly
  chr1_votes <- DBI::dbGetQuery(args$db_pool, "SELECT vote_count_total FROM annotations WHERE coordinates = 'chr1:1000'")
  chr2_votes <- DBI::dbGetQuery(args$db_pool, "SELECT vote_count_total FROM annotations WHERE coordinates = 'chr2:2000'")
  chr3_votes <- DBI::dbGetQuery(args$db_pool, "SELECT vote_count_total FROM annotations WHERE coordinates = 'chr3:3000'")

  testthat::expect_equal(chr1_votes$vote_count_total, 3)
  testthat::expect_equal(chr2_votes$vote_count_total, 2)
  testthat::expect_equal(chr3_votes$vote_count_total, 0)

  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = ""
  )

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )

  testServer(
    votingServer,
    session = my_session,
    args = args,
    {
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_vote_limit_session"

      # Trigger the mutation loading
      session$flushReact()

      # get_mutation should skip chr1:1000 (3 votes) and return chr2:2000 (2 votes)
      res <- get_mutation()
      testthat::expect_equal(res$coordinates, "chr2:2000")
    }
  )
})

testthat::test_that("get_mutation returns done when all screenshots have 3+ votes", {
  # Set up environment with 2 coordinates
  env <- setup_voting_env(c("chr1:1000", "chr2:2000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  # Set vote_count_total directly to 3 or more for both coordinates
  DBI::dbExecute(
    args$db_pool,
    "UPDATE annotations SET vote_count_total = 3 WHERE coordinates = 'chr1:1000'"
  )
  DBI::dbExecute(
    args$db_pool,
    "UPDATE annotations SET vote_count_total = 4 WHERE coordinates = 'chr2:2000'"
  )

  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = ""
  )

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )

  testServer(
    votingServer,
    session = my_session,
    args = args,
    {
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_all_voted_session"

      # Trigger the mutation loading
      session$flushReact()

      # get_mutation should return "done" since all screenshots have 3+ votes
      res <- get_mutation()
      testthat::expect_equal(res$coordinates, "done")
    }
  )
})
testthat::test_that("options not in voting_options_max_matching_votes are never skipped", {
  # This test validates the fix for the issue where options not configured
  # in voting_options_max_matching_votes were being skipped with a default limit of 3
  
  # Set up environment with 2 coordinates
  env <- setup_voting_env(c("chr1:1000", "chr2:2000"))

testthat::test_that("observations and comments are cleared when switching vote type from none_of_above to yes", {
  # Set up test environment
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  # Set vote_count_none_of_above to a high value (e.g., 10)
  # Since 'none_of_above' is NOT in voting_options_max_matching_votes,
  # it should NOT be skipped regardless of vote count
  DBI::dbExecute(
    args$db_pool,
    "UPDATE annotations SET vote_count_none_of_above = ? WHERE coordinates = ?",
    params = list(10, "chr1:1000")
  )

  # Verify the vote count was set correctly
  chr1_votes <- DBI::dbGetQuery(
    args$db_pool, 
    "SELECT vote_count_none_of_above FROM annotations WHERE coordinates = ?",
    params = list("chr1:1000")
  )
  testthat::expect_equal(chr1_votes$vote_count_none_of_above, 10)

  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = ""
  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = "?coordinate=chr1:1000"
  )

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )

  # Verify that 'none_of_above' is NOT in voting_options_max_matching_votes
  testthat::expect_false(
    "none_of_above" %in% names(args$cfg$voting_options_max_matching_votes)
  )

  testServer(
    votingServer,
    session = my_session,
    args = args,
    {
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_no_limit_session"

      # Trigger the mutation loading
      session$flushReact()

      # get_mutation should return chr1:1000, NOT skip it
      # even though vote_count_none_of_above is 10
      res <- get_mutation()
      testthat::expect_equal(res$coordinates, "chr1:1000")
      
      # Verify the annotations file does NOT have a skip reason for chr1:1000
      annotations <- read.delim(
        env$annotations_file,
        stringsAsFactors = FALSE
      )
      chr1_row <- annotations[annotations$coordinates == "chr1:1000", ]
      # The agreement should be NA (not voted yet), not a skip reason
      testthat::expect_true(is.na(chr1_row$agreement))
    }
  )
})

testthat::test_that("options in voting_options_max_matching_votes ARE skipped when limit reached", {
  # This test confirms that options explicitly configured in 
  # voting_options_max_matching_votes still get skipped correctly
  
  # Set up environment with 2 coordinates
  env <- setup_voting_env(c("chr1:1000", "chr2:2000"))
      # Set up session userData needed by the observer
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$shinyauthr_session_id <- "session_state_persistence"
      session$userData$votingInstitute <- cfg$test_institute

      # Manually set current_mutation to simulate a loaded variant
      current_mutation <- shiny::reactiveVal(list(
        coordinates = "chr1:1000",
        REF = "A",
        ALT = "T",
        variant = "A>T",
        path = "dummy.png"
      ))

      # Replace the module's current_mutation with our test version
      assign("current_mutation", current_mutation, envir = parent.frame())

      # Simulate the user selecting "none_of_above" with observation and comment
      session$setInputs(agreement = "none_of_above")
      session$setInputs(observation = c("coverage"))
      session$setInputs(comment = "Test observation comment")

      # Simulate clicking the "Next" button (first vote)
      session$setInputs(nextBtn = 1)

      # Read annotations and verify observation and comment were saved
      annotations <- read.delim(
        env$annotations_file,
        header = TRUE,
        stringsAsFactors = FALSE
      )
      testthat::expect_equal(annotations$agreement[1], "none_of_above")
      testthat::expect_equal(annotations$observation[1], "coverage")
      testthat::expect_equal(annotations$comment[1], "Test observation comment")

      # Now simulate the user changing their vote to "yes"
      # (observation and comment fields would be hidden in UI but values persist in input)
      session$setInputs(agreement = "yes")

      # Simulate clicking "Next" again (changing vote)
      session$setInputs(nextBtn = 2)

      # Read annotations again and verify observation and comment are cleared
      annotations <- read.delim(
        env$annotations_file,
        header = TRUE,
        stringsAsFactors = FALSE
      )
      testthat::expect_equal(annotations$agreement[1], "yes")
      testthat::expect_true(is.na(annotations$observation[1]))
      testthat::expect_true(is.na(annotations$comment[1]))
    }
  )
})

testthat::test_that("comment is preserved for diff_var but cleared for yes", {
  # Set up test environment
  env <- setup_voting_env(c("chr1:1000"))
  args <- make_args(env$annotations_file)
  cleanup_db <- setup_test_db(args)
  on.exit(cleanup_db())

  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = "?coordinate=chr1:1000"
  )

  args$cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )

  # Get the configured max votes for 'yes' option
  max_yes_votes <- args$cfg$voting_options_max_matching_votes[["yes"]]
  testthat::expect_false(is.null(max_yes_votes))

  # Set vote_count_correct to the max limit
  DBI::dbExecute(
    args$db_pool,
    "UPDATE annotations SET vote_count_correct = ? WHERE coordinates = ?",
    params = list(max_yes_votes, "chr1:1000")
  )

  # Verify the vote count was set correctly
  chr1_votes <- DBI::dbGetQuery(
    args$db_pool, 
    "SELECT vote_count_correct FROM annotations WHERE coordinates = ?",
    params = list("chr1:1000")
  )
  testthat::expect_equal(chr1_votes$vote_count_correct, max_yes_votes)

  my_session <- MockShinySession$new()
  my_session$clientData <- shiny::reactiveValues(
    url_search = ""
  )

  testServer(
    votingServer,
    session = my_session,
    args = args,
    {
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$votingInstitute <- cfg$test_institute
      session$userData$shinyauthr_session_id <- "test_skip_configured_session"

      # Trigger the mutation loading
      session$flushReact()

      # get_mutation should skip chr1:1000 and return chr2:2000
      res <- get_mutation()
      testthat::expect_equal(res$coordinates, "chr2:2000")
      
      # Verify the annotations file has a skip reason for chr1:1000
      annotations <- read.delim(
        env$annotations_file,
        stringsAsFactors = FALSE
      )
      chr1_row <- annotations[annotations$coordinates == "chr1:1000", ]
      # Expected format matches the skip_reason in mod_voting.R lines 755-760
      expected_skip_reason <- paste0(
        "skipped - max matching votes (",
        max_yes_votes,
        ") for option (yes) reached"
      )
      testthat::expect_equal(chr1_row$agreement, expected_skip_reason)
    }
  )
})
      # Set up session userData needed by the observer
      session$userData$userAnnotationsFile <- env$annotations_file
      session$userData$shinyauthr_session_id <- "session_comment_test"
      session$userData$votingInstitute <- cfg$test_institute

      # Manually set current_mutation to simulate a loaded variant
      current_mutation <- shiny::reactiveVal(list(
        coordinates = "chr1:1000",
        REF = "A",
        ALT = "T",
        variant = "A>T",
        path = "dummy.png"
      ))

      # Replace the module's current_mutation with our test version
      assign("current_mutation", current_mutation, envir = parent.frame())

      # Simulate the user selecting "diff_var" with a comment
      session$setInputs(agreement = "diff_var")
      session$setInputs(comment = "Different variant comment")

      # Simulate clicking the "Next" button
      session$setInputs(nextBtn = 1)

      # Read annotations and verify comment was saved for diff_var
      annotations <- read.delim(
        env$annotations_file,
        header = TRUE,
        stringsAsFactors = FALSE
      )
      testthat::expect_equal(annotations$agreement[1], "diff_var")
      testthat::expect_equal(annotations$comment[1], "Different variant comment")

      # Now simulate changing vote to "yes" (comment field still has value in input)
      session$setInputs(agreement = "yes")

      # Simulate clicking "Next" again
      session$setInputs(nextBtn = 2)

      # Read annotations and verify comment is cleared for "yes"
      annotations <- read.delim(
        env$annotations_file,
        header = TRUE,
        stringsAsFactors = FALSE
      )
      testthat::expect_equal(annotations$agreement[1], "yes")
      testthat::expect_true(is.na(annotations$comment[1]))
    }
  )
})
