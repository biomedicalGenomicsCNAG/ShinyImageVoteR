library(testthat)
library(B1MGVariantVoting)

test_that("Package functions work correctly", {
  # Test server utility functions
  expect_true(exists("schedule_logout_update"))
  expect_true(exists("cancel_pending_logout"))
  
  # Test utility functions
  expect_true(exists("create_test_db_pool"))
  expect_true(exists("generate_user_seed"))
  
  # Test app runner functions
  expect_true(exists("run_voting_app"))
  expect_true(exists("get_app_dir"))
})

test_that("Server utility functions work", {
  # Test cancel_pending_logout with non-existent session
  expect_silent(cancel_pending_logout("non_existent_session"))
  
  # Test generate_user_seed
  seed1 <- generate_user_seed("test_user", 1609459200)
  seed2 <- generate_user_seed("test_user", 1609459200)
  expect_equal(seed1, seed2)
  
  # Different users should have different seeds
  seed3 <- generate_user_seed("different_user", 1609459200)
  expect_false(seed1 == seed3)
})

test_that("Database utilities work", {
  # Test create_test_db_pool
  test_db <- create_test_db_pool()
  expect_s4_class(test_db$pool, "Pool")
  expect_true(file.exists(test_db$file))
  
  # Test basic database operations
  result <- DBI::dbGetQuery(test_db$pool, "SELECT COUNT(*) as count FROM annotations")
  expect_equal(result$count, 3)
  
  # Clean up
  pool::poolClose(test_db$pool)
  unlink(test_db$file)
})

test_that("App directory functions work", {
  app_dir <- get_app_dir()
  expect_true(nchar(app_dir) > 0)
})
