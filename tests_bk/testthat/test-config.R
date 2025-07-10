library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(shinytest2)

# Source the necessary files
source("../../config.R")
source("../../modules/login_module.R")

test_that("Configuration values are loaded correctly", {
  expect_true(exists("cfg_shutdown_file"))
  expect_true(exists("cfg_sqlite_file"))
  expect_true(exists("cfg_institute_ids"))
  expect_true(exists("cfg_credentials_df"))
  
  # Test that institute IDs are properly configured
  expect_true(length(cfg_institute_ids) > 0)
  expect_true("CNAG" %in% cfg_institute_ids)
  expect_true("Training_answers_not_saved" %in% cfg_institute_ids)
  
  # Test credentials data frame structure
  expect_true(is.data.frame(cfg_credentials_df))
  expect_true("user" %in% names(cfg_credentials_df))
  expect_true("password" %in% names(cfg_credentials_df))
  
  # Test vote mapping configuration
  expect_true(exists("cfg_vote2dbcolumn_map"))
  expect_equal(length(cfg_vote2dbcolumn_map), 4)
  expect_true(all(c("yes", "no", "diff_var", "not_confident") %in% names(cfg_vote2dbcolumn_map)))
})

test_that("Database column configuration is correct", {
  expect_true(exists("cfg_db_general_cols"))
  expect_true(exists("cfg_vote_counts_cols"))
  expect_true(exists("cfg_db_cols"))
  
  # Test that general columns contain expected fields
  expected_general_cols <- c("coordinates", "REF", "ALT", "variant", "path")
  expect_equal(cfg_db_general_cols, expected_general_cols)
  
  # Test that vote count columns are properly defined
  expect_true(all(c("vote_count_correct", "vote_count_no_variant", 
                   "vote_count_different_variant", "vote_count_not_sure",
                   "vote_count_total") %in% cfg_vote_counts_cols))
})

test_that("User annotations configuration is valid", {
  expect_true(exists("cfg_user_annotations_colnames"))
  expected_cols <- c("coordinates", "agreement", "alternative_vartype", 
                    "observation", "comment", "shinyauthr_session_id", 
                    "time_till_vote_casted_in_seconds")
  expect_equal(cfg_user_annotations_colnames, expected_cols)
})

test_that("Nucleotide color mapping is complete", {
  expect_true(exists("cfg_nt2color_map"))
  expect_true(all(c("T", "C", "A", "G", "-") %in% names(cfg_nt2color_map)))
  expect_equal(length(cfg_nt2color_map), 5)
})
