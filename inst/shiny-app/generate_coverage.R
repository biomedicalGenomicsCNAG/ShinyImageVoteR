#!/usr/bin/env Rscript

# Generate test coverage report for the B1MG variant voting application
library(covr)
library(testthat)

cat("Generating test coverage report...\n")

# Set working directory
setwd("/home/ivo/projects/bioinfo/cnag/repos/B1MG-variant-voting/R")

# Define the source files to include in coverage
source_files <- c(
  "config.R",
  "server_utils.R",
  "ui.R",
  "modules/login_module.R",
  "modules/voting_module.R", 
  "modules/leaderboard_module.R",
  "modules/user_stats_module.R",
  "modules/about_module.R"
)

# Filter to only existing files
existing_files <- source_files[file.exists(source_files)]
cat("Source files to analyze:\n")
cat(paste("  -", existing_files), sep = "\n")

# Generate coverage report
tryCatch({
  # Run coverage analysis
  coverage_result <- file_coverage(
    source_files = existing_files,
    test_files = list.files("tests/testthat", pattern = "^test-.*\\.R$", full.names = TRUE)
  )
  
  # Print coverage summary
  cat("\n=== COVERAGE SUMMARY ===\n")
  print(coverage_result)
  
  # Calculate overall coverage percentage
  total_lines <- sum(coverage_result$totalcount)
  covered_lines <- sum(coverage_result$value)
  coverage_percent <- round((covered_lines / total_lines) * 100, 2)
  
  cat(sprintf("\nOverall Coverage: %.2f%% (%d/%d lines covered)\n", 
              coverage_percent, covered_lines, total_lines))
  
  # Generate HTML report
  cat("\nGenerating HTML coverage report...\n")
  report_file <- "coverage_report.html"
  
  # Create HTML report
  report_html <- covr:::to_html(coverage_result)
  writeLines(report_html, report_file)
  
  cat(sprintf("HTML report saved to: %s\n", normalizePath(report_file)))
  
  # Generate detailed coverage by file
  cat("\n=== COVERAGE BY FILE ===\n")
  file_coverage <- aggregate(
    cbind(value = coverage_result$value, totalcount = coverage_result$totalcount),
    by = list(file = coverage_result$filename),
    FUN = sum
  )
  file_coverage$percent <- round((file_coverage$value / file_coverage$totalcount) * 100, 2)
  
  for (i in 1:nrow(file_coverage)) {
    cat(sprintf("%-30s: %6.2f%% (%3d/%3d lines)\n", 
                basename(file_coverage$file[i]),
                file_coverage$percent[i],
                file_coverage$value[i],
                file_coverage$totalcount[i]))
  }
  
  # Save detailed coverage data
  coverage_data <- data.frame(
    file = coverage_result$filename,
    line = coverage_result$line,
    value = coverage_result$value,
    totalcount = coverage_result$totalcount,
    functions = coverage_result$functions
  )
  write.csv(coverage_data, "coverage_details.csv", row.names = FALSE)
  cat(sprintf("\nDetailed coverage data saved to: %s\n", normalizePath("coverage_details.csv")))
  
}, error = function(e) {
  cat("Error generating coverage report:", conditionMessage(e), "\n")
  
  # Fallback: try with package_coverage if file_coverage fails
  cat("Trying alternative coverage method...\n")
  tryCatch({
    # Try package coverage (treats directory as package)
    pkg_coverage <- package_coverage(path = ".", type = "tests")
    cat("\n=== PACKAGE COVERAGE SUMMARY ===\n")
    print(pkg_coverage)
    
    # Generate HTML report
    report_file <- "coverage_report.html"
    covr:::to_html(pkg_coverage, file = report_file)
    cat(sprintf("HTML report saved to: %s\n", normalizePath(report_file)))
    
  }, error = function(e2) {
    cat("Alternative coverage method also failed:", conditionMessage(e2), "\n")
    cat("This might be because the project is not structured as an R package.\n")
  })
})

cat("\nCoverage analysis complete!\n")
