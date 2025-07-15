library(testthat)
library(shiny)
library(jsonlite)
library(digest)
library(DBI)
library(RSQLite)
library(pool)
library(later)
library(ShinyImgVoteR)

test_that("Logout scheduling functions work correctly", {
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool

  # Test cancel_pending_logout with non-existent session
  expect_silent(ShinyImgVoteR::cancel_pending_logout("non_existent_session"))
  
  # Debug: Check if functions exist
  expect_true(exists("schedule_logout_update"))
  expect_true(exists("cancel_pending_logout"))
  expect_true(exists("pending_logout_tasks"))
  
  # Test schedule_logout_update with longer delay to check scheduling
  callback_executed <- FALSE
  callback <- function() { 
    cat("Callback executed!\n")
    callback_executed <<- TRUE 
  }
  
  # Schedule with longer delay to test that it gets scheduled
  schedule_logout_update("test_session", callback, delay = 0.5)
  
  # Check that task was scheduled (should exist immediately after scheduling)
  expect_true(exists("test_session", envir = pending_logout_tasks))
  
  # Cancel it before execution
  cancel_pending_logout("test_session")
  expect_false(exists("test_session", envir = pending_logout_tasks))
  
  # Test actual execution with shorter delay
  callback_executed_2 <- FALSE
  callback_2 <- function() { 
    cat("Callback 2 executed!\n")
    callback_executed_2 <<- TRUE 
  }
  
  # Schedule with very short delay for testing execution
  schedule_logout_update("test_session_2", callback_2, delay = 0.1)
  
  # Wait for callback execution and process the event loop
  cat("Waiting for callback 2...\n")
  
  # Process the later event loop to execute scheduled tasks
  start_time <- Sys.time()
  while (!callback_executed_2 && difftime(Sys.time(), start_time, units = "secs") < 1) {
    later::run_now(timeoutSecs = 0.01)
    Sys.sleep(0.01)
  }
  
  cat("Callback 2 executed status:", callback_executed_2, "\n")
  expect_true(callback_executed_2)
  
  # Check that task was cleaned up after execution
  expect_false(exists("test_session_2", envir = pending_logout_tasks))
  
  # Verify first callback was NOT executed (since it was cancelled)
  expect_false(callback_executed)

  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
})