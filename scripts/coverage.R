#!/usr/bin/env Rscript
# coverage.R: Generate test coverage including R/ and inst/shiny-app/modules

# Load covr
if (!requireNamespace("covr", quietly = TRUE)) {
  install.packages("covr", repos = "https://cloud.r-project.org")
}
library(covr)

# Prepare dummy dependencies under inst/shiny-app for includeScript and includeMarkdown
inst_app <- file.path(getwd(), "inst", "shiny-app")

# Dummy www directory and hotkeys.js
www_dir <- file.path(inst_app, "www")
if (!dir.exists(www_dir)) dir.create(www_dir, recursive = TRUE)
hotkey_path <- file.path(www_dir, "hotkeys.js")
if (!file.exists(hotkey_path)) file.create(hotkey_path)

# Dummy docs directory and faq.md
docs_dir <- file.path(inst_app, "docs")
if (!dir.exists(docs_dir)) dir.create(docs_dir, recursive = TRUE)
faq_path <- file.path(docs_dir, "faq.md")
if (!file.exists(faq_path)) file.create(faq_path)

# 1. Compute coverage for package R/ code
cov_r <- package_coverage(
  path = ".",
  type = "tests"
)

# 2. Compute coverage for inst/shiny-app/modules separately
modules_dir <- file.path(inst_app, "modules")
mod_files <- if (dir.exists(modules_dir)) {
  list.files(modules_dir, pattern = "\\.R$", full.names = TRUE)
} else {
  character()
}

test_files <- list.files("tests/testthat", pattern = "\\.R$", full.names = TRUE)

cov_mod <- if (length(mod_files) > 0) {
  file_coverage(source_files = mod_files, test_files = test_files)
} else {
  NULL
}

combined_cov <- c(cov_r, cov_mod)
attr(combined_cov, "class") <- attr(cov_r, "class")
attr(combined_cov, "package") <- attr(cov_r, "package")
attr(combined_cov, "relative") <- attr(cov_r, "relative")

# covr::codecov(coverage = combined_cov)

# 4. Write HTML report to project root
report(combined_cov, file = file.path(getwd(), "coverage.html"))

# Print summary to console
cat("Total Coverage:", percent_coverage(combined_cov), "%\n")
