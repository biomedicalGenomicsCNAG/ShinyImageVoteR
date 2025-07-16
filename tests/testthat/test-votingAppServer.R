library(testthat)
library(shiny)
library(ShinyImgVoteR)

# stub loginServer and logoutServer to control their behavior
# Global variables used by the stubs
.test_login_rv <- NULL
.update_called <- NULL

stub_loginServer <- function(id, db_conn = NULL, log_out = reactive(NULL)) {
  .test_login_rv <<- shiny::reactiveVal()
  list(
    login_data = reactive(.test_login_rv()),
    credentials = reactive(list(user_auth = TRUE)),
    update_logout_time = function(sessionid, conn = NULL) {
      .update_called <<- sessionid
    }
  )
}

testthat::test_that("login event creates user data files", {
  if (interactive()) {
    source_helpers <- function(path = "tests/testthat") {
      helper_files <- list.files(path, pattern = "^helper-.*\\.R$", full.names = TRUE)
      lapply(helper_files, source)
    }
    source_helpers()
  }
  
  mock_db <- create_mock_db()
  pool <- mock_db$pool
  temp_user_dir <- tempfile()
  dir.create(temp_user_dir)

  withr::local_envvar(
    IMGVOTER_USER_DATA_DIR = temp_user_dir,
    IMGVOTER_SERVER_DATA_DIR = temp_user_dir
  )

  # browser()
  # debugonce(ShinyImgVoteR::makeVotingAppServer)

  testthat::with_mocked_bindings(
    .package = "ShinyImgVoteR",
    `loginServer` = stub_loginServer,
    {
      testServer(ShinyImgVoteR::makeVotingAppServer(pool), {
        # browser()
        # Trigger login
        .test_login_rv(list(
          user_id = "user", 
          institute = "institute1", 
          session_id = "sess1"
        ))
        session$flushReact()

        user_path <- file.path(temp_user_dir, "institute1", "user")
        testthat::expect_true(dir.exists(user_path))

        info_file <- file.path(user_path, "user_info.json")
        ann_file <- file.path(user_path, "user_annotations.tsv")
        testthat::expect_true(file.exists(info_file))
        testthat::expect_true(file.exists(ann_file))
        testthat::expect_equal(get_mutation_trigger_source(), "url-params-change")
      })
    }
  )

  poolClose(pool)
  unlink(mock_db$file)
})


testthat::test_that("user_stats_tab_trigger returns timestamp when tab selected", {
  mock_pool <- create_mock_db()$pool

  testServer(ShinyImgVoteR::makeVotingAppServer(mock_pool), {
    session$setInputs(main_navbar = "User stats")
    expect_s3_class(user_stats_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(user_stats_tab_trigger())
  })

  # cleanup
  poolClose(mock_pool)
})

testthat::test_that("leaderboard_tab_trigger returns timestamp when tab selected", {
  mock_pool <- create_mock_db()$pool

  testServer(ShinyImgVoteR::makeVotingAppServer(mock_pool), {
    session$setInputs(main_navbar = "Leaderboard")
    expect_s3_class(leaderboard_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(leaderboard_tab_trigger())
  })

  # cleanup
  poolClose(mock_pool)
})

testthat::test_that("session end triggers scheduled logout update", {
  mock_db <- create_mock_db()
  pool <- mock_db$pool
  temp_user_dir <- tempfile()
  dir.create(temp_user_dir)
  
  # Reset global test variables
  .test_login_rv <<- NULL
  .update_called <<- 
  
  # stub schedule_logout_update so it just runs the callback immediately
  stub_schedule_logout_update <- function(session_id, callback) {
    callback()
    .update_called <<- session_id
  }
  
  withr::local_envvar(
    IMGVOTER_USER_DATA_DIR = temp_user_dir,
    IMGVOTER_SERVER_DATA_DIR = temp_user_dir
  )
  
  with_mocked_bindings(
    `loginServer` = stub_loginServer,
    `schedule_logout_update` = stub_schedule_logout_update,
    {
      testServer(ShinyImgVoteR::makeVotingAppServer(pool), {
        # First, simulate a login to set up session data
        .test_login_rv(list(
          user_id = "user1", 
          institute = "CNAG", 
          session_id = "test_session_456"
        ))
        session$flushReact()
        
        # Verify session data is set
        testthat::expect_equal(
          session$userData$shinyauthr_session_id, 
          "test_session_456"
        )

        session$close()
        session$flushReact()
      })
    }
  )
  testthat::expect_equal(.update_called, "test_session_456")

  poolClose(pool)
  unlink(mock_db$file)
  unlink(temp_user_dir, recursive = TRUE)
})