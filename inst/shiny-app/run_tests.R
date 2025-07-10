#!/usr/bin/env Rscript

# Test runner script for the B1MG Variant Voting application
# Usage: Rscript run_tests.R

library(testthat)

# Set working directory to the directory containing this script
args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("--file=", args, value = TRUE)
if (length(file_arg) == 1) {
  script_path <- sub("--file=", "", file_arg)
  setwd(dirname(normalizePath(script_path)))
}

# Source configuration and required libraries
source("config.R")

# Run all tests
cat("Running tests for B1MG Variant Voting application...\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Test configuration
cat("\nTesting configuration...\n")
test_file("tests/testthat/test-config.R")

# Test utilities
cat("\nTesting utility functions...\n")
test_file("tests/testthat/test-utils.R")

# Test database functionality
cat("\nTesting database functionality...\n")
test_file("tests/testthat/test-database.R")

# Test login module
cat("\nTesting login module...\n")
test_file("tests/testthat/test-login-module.R")

# Test voting module
cat("\nTesting voting module...\n")
test_file("tests/testthat/test-voting-module.R")

# Test leaderboard module
cat("\nTesting leaderboard module...\n")
test_file("tests/testthat/test-leaderboard-module.R")

# Test user stats module
cat("\nTesting user stats module...\n")
test_file("tests/testthat/test-user-stats-module.R")

# Test server functions
cat("\nTesting server functions...\n")
test_file("tests/testthat/test-server-functions.R")

# Test UI
cat("\nTesting UI components...\n")
test_file("tests/testthat/test-ui.R")

# Run all tests at once (alternative approach)
cat("\n", paste(rep("=", 50), collapse = ""))
cat("\nRunning complete test suite...\n")
test_results <- test_dir("tests/testthat")

# Print summary
cat("\n", paste(rep("=", 50), collapse = ""))
cat("\nTest Summary:\n")
print(test_results)

if (requireNamespace("covr", quietly = TRUE)) {
  cat("\nCalculating coverage...\n")
  cov <- covr::package_coverage()
  print(cov)
} else {
  cat("\nPackage 'covr' not installed; skipping coverage.\n")
}

cat("\nTests completed!\n")
