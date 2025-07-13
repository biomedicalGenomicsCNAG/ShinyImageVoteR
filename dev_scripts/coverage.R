#!/usr/bin/env Rscript
# coverage.R: Generate test coverage

library(magrittr)

cov <- covr::package_coverage()
# covr::codecov(coverage = cov)

cov_dir <- file.path(getwd(), "tests", "coverage")
covr::report(cov, file.path(cov_dir, "coverage.html"))

# Print summary to console
cat("Total Coverage:", covr::percent_coverage(cov), "%\n")

more_details <- FALSE
if (!more_details) {
  q()
}

covr::to_cobertura(cov, file.path(cov_dir, "cobertura.xml"))
covr::to_sonarqube(cov, file.path(cov_dir, "sonarqube.xml"))

zero_cov <- covr::zero_coverage(cov)

coverage_dfs <- list(
  coverage = cov,
  zero_coverage = zero_cov
)

lapply(names(coverage_dfs), function(name) {
  write.csv(
    file.path(cov_dir, paste0(name, ".csv")))
})
