library(testthat)
library(shiny)
library(B1MGVariantVoting)

# stub loginServer and logoutServer to control their behavior
# Global variables used by the stubs
.test_login_rv <- NULL
.update_called <- NULL

stub_loginServer <- function(id, db_conn = NULL, log_out = reactive(NULL)) {
  .test_login_rv <<- reactiveVal()
  list(
    login_data = reactive(.test_login_rv()),
    credentials = reactive(list(user_auth = TRUE)),
    update_logout_time = function(sessionid, conn = NULL) {
      .update_called <<- sessionid
    }
  )
}

test_that("login event creates user data files", {
  mock_db <- create_mock_db()
  pool <- mock_db$pool
  temp_user_dir <- tempfile()
  dir.create(temp_user_dir)

  withr::local_envvar(
    B1MG_USER_DATA_DIR = temp_user_dir,
    B1MG_SERVER_DATA_DIR = temp_user_dir
  )

  with_mocked_bindings(
    `loginServer` = stub_loginServer,
    {
      testServer(B1MGVariantVoting::makeVotingAppServer(pool), {
        # Trigger login
        .test_login_rv(list(user_id = "user1", voting_institute = "CNAG", session_id = "sess1"))
        session$flushReact()

        user_path <- file.path(temp_user_dir, "CNAG", "user1")
        expect_true(dir.exists(user_path))

        info_file <- file.path(user_path, "user1_info.json")
        ann_file <- file.path(user_path, "user1_annotations.tsv")
        expect_true(file.exists(info_file))
        expect_true(file.exists(ann_file))
        expect_equal(get_mutation_trigger_source(), "url-params-change")
      })
    }
  )

  poolClose(pool)
  unlink(mock_db$file)
})


test_that("user_stats_tab_trigger returns timestamp when tab selected", {
  mock_pool <- create_mock_db()$pool

  testServer(B1MGVariantVoting::makeVotingAppServer(mock_pool), {
    session$setInputs(main_navbar = "User stats")
    expect_s3_class(user_stats_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(user_stats_tab_trigger())
  })

  # cleanup
  poolClose(mock_pool)
})

test_that("leaderboard_tab_trigger returns timestamp when tab selected", {
  mock_pool <- create_mock_db()$pool

  testServer(B1MGVariantVoting::makeVotingAppServer(mock_pool), {
    session$setInputs(main_navbar = "Leaderboard")
    expect_s3_class(leaderboard_tab_trigger(), "POSIXt")
    session$setInputs(main_navbar = "Other")
    expect_null(leaderboard_tab_trigger())
  })

  # cleanup
  poolClose(mock_pool)
})

test_that("session end triggers scheduled logout update", {
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
    B1MG_USER_DATA_DIR = temp_user_dir,
    B1MG_SERVER_DATA_DIR = temp_user_dir
  )
  
  with_mocked_bindings(
    `loginServer` = stub_loginServer,
    `schedule_logout_update` = stub_schedule_logout_update,
    {
      testServer(B1MGVariantVoting::makeVotingAppServer(pool), {
        # First, simulate a login to set up session data
        .test_login_rv(list(
          user_id = "user1", 
          voting_institute = "CNAG", 
          session_id = "test_session_456"
        ))
        session$flushReact()
        
        # Verify session data is set
        expect_equal(
          session$userData$shinyauthr_session_id, 
          "test_session_456"
        )

        session$close()
        session$flushReact()
      })
    }
  )
  expect_equal(.update_called, "test_session_456")

  poolClose(pool)
  unlink(mock_db$file)
  unlink(temp_user_dir, recursive = TRUE)
})