library(testthat)
library(B1MGVariantVoting)

test_that("Package functions work correctly", {
  # Test server utilities
  expect_true(exists("schedule_logout_update"))
  expect_true(exists("cancel_pending_logout"))
  
  # Test that the functions are exported
  expect_true("schedule_logout_update" %in% ls("package:B1MGVariantVoting"))
  expect_true("cancel_pending_logout" %in% ls("package:B1MGVariantVoting"))
  
  # Test utility functions
  expect_true(exists("create_test_db_pool"))
  expect_true(exists("generate_user_seed"))
  
  # Test app functions
  expect_true(exists("run_voting_app"))
  expect_true(exists("get_app_dir"))
})

test_that("Database utilities work", {
  # Test create_test_db_pool
  test_db <- create_test_db_pool()
  expect_true(is.list(test_db))
  expect_true("pool" %in% names(test_db))
  expect_true("file" %in% names(test_db))
  
  # Test database operations
  result <- DBI::dbGetQuery(test_db$pool, "SELECT COUNT(*) as count FROM annotations")
  expect_equal(result$count, 3)
  
  # Clean up
  pool::poolClose(test_db$pool)
  unlink(test_db$file)
})

test_that("Seed generation works", {
  # Test generate_user_seed
  seed1 <- generate_user_seed("test_user", 1609459200)
  seed2 <- generate_user_seed("test_user", 1609459200)
  
  # Should be identical with same inputs
  expect_equal(seed1, seed2)
  
  # Should be different with different inputs
  seed3 <- generate_user_seed("different_user", 1609459200)
  expect_false(seed1 == seed3)
  
  # Should be numeric
  expect_true(is.numeric(seed1))
})
