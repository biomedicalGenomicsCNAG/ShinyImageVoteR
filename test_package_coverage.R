#!/usr/bin/env Rscript

# Test coverage for the installed B1MGVariantVoting package
library(testthat)
library(covr)

cat("Testing coverage for B1MGVariantVoting package...\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Test that the package loads correctly
tryCatch({
  library(B1MGVariantVoting)
  cat("✓ Package loaded successfully\n")
}, error = function(e) {
  cat("✗ Error loading package:", conditionMessage(e), "\n")
  stop("Package loading failed")
})

# Test basic package functions
cat("\nTesting basic package functions...\n")

# Test server utils functions
tryCatch({
  # Test that functions exist
  stopifnot(exists("schedule_logout_update"))
  stopifnot(exists("cancel_pending_logout"))
  cat("✓ Server utility functions available\n")
}, error = function(e) {
  cat("✗ Server utility functions not available:", conditionMessage(e), "\n")
})

# Test utility functions
tryCatch({
  stopifnot(exists("create_test_db_pool"))
  stopifnot(exists("generate_user_seed"))
  cat("✓ Utility functions available\n")
}, error = function(e) {
  cat("✗ Utility functions not available:", conditionMessage(e), "\n")
})

# Test app runner
tryCatch({
  stopifnot(exists("run_voting_app"))
  stopifnot(exists("get_app_dir"))
  cat("✓ App runner functions available\n")
}, error = function(e) {
  cat("✗ App runner functions not available:", conditionMessage(e), "\n")
})

# Now test coverage
cat("\nRunning coverage analysis...\n")

tryCatch({
  # Run package coverage
  coverage_result <- package_coverage()
  
  cat("\n=== COVERAGE RESULTS ===\n")
  print(coverage_result)
  
  # Generate coverage percentage
  coverage_percent <- percent_coverage(coverage_result)
  cat(sprintf("\nOverall Coverage: %.2f%%\n", coverage_percent))
  
  # Generate detailed HTML report
  cat("\nGenerating HTML coverage report...\n")
  report_file <- "package_coverage_report.html"
  
  # Save coverage report
  covr:::to_html(coverage_result, file = report_file)
  cat(sprintf("HTML report saved to: %s\n", normalizePath(report_file)))
  
  # Show coverage by file
  cat("\n=== COVERAGE BY FILE ===\n")
  coverage_df <- tally_coverage(coverage_result)
  print(coverage_df)
  
}, error = function(e) {
  cat("Error running package coverage:", conditionMessage(e), "\n")
  
  # Fallback: run basic test coverage
  cat("\nTrying test-only coverage...\n")
  tryCatch({
    test_coverage_result <- test_coverage()
    cat("Test coverage completed successfully\n")
    print(test_coverage_result)
  }, error = function(e2) {
    cat("Test coverage also failed:", conditionMessage(e2), "\n")
  })
})

cat("\nCoverage analysis complete!\n")
