#!/usr/bin/env Rscript

# Debug script to check actual UI HTML output
library(shiny)

# Set working directory to R folder
setwd("/home/ivo/projects/bioinfo/cnag/repos/B1MG-variant-voting/R")

# Create temporary www and docs directories
dir.create("www", showWarnings = FALSE)
dir.create("docs", showWarnings = FALSE)

# Create minimal required files
writeLines("// Mock hotkeys.js", "www/hotkeys.js")
writeLines("# FAQ\nTest FAQ content", "docs/faq.md")

# Source required files
source("config.R")
source("modules/login_module.R")
source("modules/voting_module.R")
source("modules/leaderboard_module.R")
source("modules/user_stats_module.R")
source("modules/about_module.R")
source("ui.R")

# Generate HTML and print it
ui_html <- as.character(ui)
cat("=== FULL UI HTML ===\n")
cat(ui_html)
cat("\n\n=== ANALYSIS ===\n")

# Check specific patterns
patterns <- c(
  "fluidPage",
  "shiny-panel-conditional", 
  "navbarPage",
  "tab-pane",
  "about",
  "login",
  "voting",
  "leaderboard",
  "userstats"
)

for (pattern in patterns) {
  found <- grepl(pattern, ui_html, ignore.case = TRUE)
  cat(sprintf("Pattern '%s': %s\n", pattern, if(found) "FOUND" else "NOT FOUND"))
}

# Clean up
unlink("www", recursive = TRUE)
unlink("docs", recursive = TRUE)
