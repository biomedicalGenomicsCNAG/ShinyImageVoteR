#!/usr/bin/env Rscript
# coverage.R: Generate test coverage

cov_r <- covr::package_coverage()
# covr::codecov(coverage = cov_r)

covr::report(cov_r, file = file.path(getwd(), "coverage.html"))

# Print summary to console
cat("Total Coverage:", covr::percent_coverage(cov_r), "%\n")