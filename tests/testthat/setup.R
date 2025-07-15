# Test setup file
# This file runs before all tests

# Load required packages
library(testthat)
library(ShinyImgVoteR)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(later)

# Create a temporary directory for test files
test_temp_dir <- tempdir()

# Helper function to get app directory for tests
get_test_app_dir <- function() {
  system.file("shiny-app", package = "ShinyImgVoteR")
}
