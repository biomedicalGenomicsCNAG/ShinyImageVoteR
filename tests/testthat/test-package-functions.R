library(testthat)
library(B1MGVariantVoting)

test_that("Server utility functions work", {
  # Test cancel_pending_logout with non-existent session
  expect_silent(cancel_pending_logout("non_existent_session"))
  
  # Test that functions exist and are callable
  expect_true(is.function(schedule_logout_update))
  expect_true(is.function(cancel_pending_logout))
})

test_that("Database utility functions work", {
  # Test database pool creation
  test_db <- create_mock_db()
  expect_true(is.list(test_db))
  expect_true("pool" %in% names(test_db))
  expect_true("file" %in% names(test_db))
  
  # Clean up
  pool::poolClose(test_db$pool)
  unlink(test_db$file)
})

test_that("Utility functions work", {
  # Test seed generation
  seed1 <- generate_user_seed("test_user", 1609459200)
  seed2 <- generate_user_seed("test_user", 1609459200)
  
  # Should be identical for same input
  expect_equal(seed1, seed2)
  
  # Should be different for different users
  seed3 <- generate_user_seed("different_user", 1609459200)
  expect_false(seed1 == seed3)
})

test_that("App runner functions exist", {
  # Test that app runner functions exist
  expect_true(is.function(run_voting_app))
  expect_true(is.function(get_app_dir))
  
  # Test app directory detection
  app_dir <- get_app_dir()
  expect_true(is.character(app_dir))
})
