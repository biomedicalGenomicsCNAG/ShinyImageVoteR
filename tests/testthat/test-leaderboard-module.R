library(testthat)
library(shiny)
library(ShinyImgVoteR)

cfg <- ShinyImgVoteR::load_config()

testthat::test_that("Leaderboard module UI renders correctly", {
  cfg <- ShinyImgVoteR::load_config()
  ui_result <- ShinyImgVoteR::leaderboardUI("test", cfg)
  expect_s3_class(ui_result, "shiny.tag.list")
  
  ui_html <- as.character(ui_result)
  testthat::expect_true(grepl("institutes_voting_counts", ui_html))
  testthat::expect_true(grepl("refresh_counts", ui_html))
})

testthat::test_that("Leaderboard server handles tab trigger parameter", {
  cfg <- ShinyImgVoteR::load_config()
  # Test that the function accepts the new tab_trigger parameter
  testServer(leaderboardServer, args = list(
    cfg,
    login_trigger = reactive({ list(user_id = "test", voting_institute = "CNAG") }),
    tab_trigger = reactive({ Sys.time() })
  ), {
    # Basic test that the server function loads without error
    testthat::expect_true(TRUE)
  })
})

testthat::test_that("Leaderboard reactive triggers correctly", {
  cfg <- ShinyImgVoteR::load_config()
  Sys.setenv(
    IMGVOTER_USER_GROUPS_COMMA_SEPARATED = paste(cfg$institute_ids, collapse = ",")
  )

  # Test with different trigger scenarios
  login_trigger <- shiny::reactiveVal(list(user_id = "test_user", voting_institute = "CNAG"))
  tab_trigger <- shiny::reactiveVal(NULL)
  
  # browser()

  # Create test directory structure
  temp_dir <- tempdir()
  test_user_data_dir <- file.path(temp_dir, "user_data")
  
  # Set up test environment
  old_wd <- getwd()
  setwd(temp_dir)
  
  # Create test institute directories and files
  for (institute in cfg$institute_ids[1:2]) {  # Test with first 2 institutes
    institute_dir <- file.path("user_data", institute)
    dir.create(institute_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Create a test user directory and annotations file
    user_dir <- file.path(institute_dir, "test_user")
    dir.create(user_dir, showWarnings = FALSE)
    
    annotations_file <- file.path(user_dir, "test_user_annotations.tsv")
    write.table(
      data.frame(
        coordinates = c("chr1:1000", "chr2:2000"),
        agreement = c("yes", "no"),
        alternative_vartype = c("", ""),
        observation = c("", ""),
        comment = c("", ""),
        shinyauthr_session_id = c("session1", "session1"),
        time_till_vote_casted_in_seconds = c("5", "3")
      ),
      file = annotations_file,
      sep = "\t",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE
    )
  }
  
  shiny::testServer(ShinyImgVoteR::leaderboardServer, args = list(
    cfg,
    login_trigger = login_trigger,
    tab_trigger = tab_trigger
  ), {
    # browser()
    # Test that reactive exists and can be triggered
    testthat::expect_true(is.reactive(counts))
    
    # Trigger tab change
    tab_trigger(Sys.time())
    
    # The counts should update
    result <- counts()
    testthat::expect_true(is.data.frame(result))
    testthat::expect_true("institute" %in% names(result))
    testthat::expect_true("users" %in% names(result))
    testthat::expect_true("total_images_voted" %in% names(result))
  })
  
  # Clean up
  setwd(old_wd)
  unlink(test_user_data_dir, recursive = TRUE)
})

testthat::test_that("Leaderboard works without tab trigger (backward compatibility)", {
  cfg <- ShinyImgVoteR::load_config()
  # Test that the module still works when tab_trigger is not provided
  login_trigger <- shiny::reactiveVal(list(user_id = "test_user", voting_institute = "CNAG"))
  
  # Create minimal test environment
  temp_dir <- base::tempdir()
  old_wd <- getwd()
  setwd(temp_dir)
  
  # Create minimal directory structure
  dir.create(file.path("user_data", cfg$institute_ids[1]), recursive = TRUE, showWarnings = FALSE)
  
  shiny::testServer(leaderboardServer, args = list(
    cfg,
    login_trigger = login_trigger
    # Note: no tab_trigger parameter - testing backward compatibility
  ), {
    # Test that reactive exists and works without tab trigger
    testthat::expect_true(is.reactive(counts))
    
    # The counts should work even without tab trigger
    result <- counts()
    testthat::expect_true(is.data.frame(result))
  })
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, "user_data"), recursive = TRUE)
})
