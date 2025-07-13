#!/usr/bin/env Rscript
# coverage.R: Generate test coverage

library(magrittr)

cov <- covr::package_coverage(quiet = FALSE)
# covr::codecov(coverage = cov)

cov_dir <- file.path(getwd(), "tests", "coverage")
covr::report(cov, file.path(cov_dir, "coverage.html"))

# Print summary to console
cat("Total Coverage:", covr::percent_coverage(cov), "%\n")

# more_details <- TRUE
more_details <- FALSE
if (!more_details) {
  q()
}

covr::to_cobertura(cov, file.path(cov_dir, "cobertura.xml"))
covr::to_sonarqube(cov, file.path(cov_dir, "sonarqube.xml"))

zero_cov <- covr::zero_coverage(cov)
cat("Total lines with zero coverage:", nrow(zero_cov), "\n")

covr_res <- list(
  coverage = cov,
  zero_coverage = zero_cov
)

# Write to CSV files
for (name in names(covr_res)) {
  df <- as.data.frame(covr_res[[name]])
  if (nrow(df) > 0) {
    file_path <- file.path(cov_dir, paste0(name, ".csv"))
    write.csv(df, file_path, row.names = FALSE)
    cat("Wrote", nrow(df), "rows to", file_path, "\n")
  } else {
    cat("No data to write for", name, "\n")
  }
}
