library(testthat)
library(shiny)
library(shinytest2)
library(ShinyImgVoteR)

# locate the directory where inst/shiny-app was installed
# app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")
cfg <- ShinyImgVoteR::load_config(
  config_file_path = system.file(
    "shiny-app",
    "default_env",
    "config",
    "config.yaml",
    package = "ShinyImgVoteR"
  )
)
ui <- votingAppUI(cfg)

# source necessary files
# source(file.path(app_dir, "config.R"))
# source(file.path(app_dir, "modules", "about_module.R"))
# source(file.path(app_dir, "modules", "login_module.R"))
# source(file.path(app_dir, "modules", "voting_module.R"))
# source(file.path(app_dir, "modules", "leaderboard_module.R"))
# source(file.path(app_dir, "modules", "user_stats_module.R"))
# source(file.path(app_dir, "ui.R"))

# Create temporary www directory and hotkeys.js file for testing
temp_www_dir <- file.path(getwd(), "www")
# write www_dir to file for debugging
dir.create(temp_www_dir, showWarnings = FALSE)

# Create temporary docs directory and faq.md file for testing
temp_docs_dir <- file.path(getwd(), "docs")
dir.create(temp_docs_dir, showWarnings = FALSE)

# Create a minimal hotkeys.js file for testing
hotkeys_content <- "// Mock hotkeys.js for testing\nconsole.log('Hotkeys loaded');"
writeLines(hotkeys_content, file.path(temp_www_dir, "hotkeys.js"))

# Create a minimal faq.md file for testing
faq_content <- "# Frequently Asked Questions\n\nThis is a mock FAQ file for testing purposes.\n\n## Question 1\nAnswer 1\n\n## Question 2\nAnswer 2"
writeLines(faq_content, file.path(temp_docs_dir, "faq.md"))

testthat::test_that("Main UI structure is correct", {
  # Test that UI function exists and returns a valid UI
  ui_result <- votingAppUI(cfg)
  expect_s3_class(ui_result, "shiny.tag.list")
  
  # Convert to HTML to check structure
  ui_html <- as.character(ui_result)
  
  # Check for essential UI components
  testthat::expect_true(grepl("container-fluid", ui_html))
  testthat::expect_true(grepl("shiny-panel-conditional", ui_html))
  
  # Check for module UIs
  testthat::expect_true(grepl("login", ui_html))
  testthat::expect_true(grepl("voting", ui_html))
  testthat::expect_true(grepl("leaderboard", ui_html))
  testthat::expect_true(grepl("userstats", ui_html))
  testthat::expect_true(grepl("About", ui_html))
})

testthat::test_that("Conditional panels are properly configured", {
  ui_result <- votingAppUI(cfg)
  ui_html <- as.character(ui_result)
  
  # Check for logged in condition
  testthat::expect_true(grepl("output.logged_in", ui_html))
  
  # Check for login panel when not logged in
  testthat::expect_true(grepl("!output.logged_in", ui_html))
})

testthat::test_that("UI configuration values are used correctly", {
  # Test that application title is used
  ui_result <- votingAppUI(cfg)
  ui_html <- as.character(ui_result)
  
  # Should contain the configured application title
  testthat::expect_true(grepl("B1MG", ui_html) || grepl("Voting", ui_html))
})

testthat::test_that("Navigation structure is present", {
  ui_result <- votingAppUI(cfg)
  ui_html <- as.character(ui_result)
  
  # Check for navigation elements (tabs, menu items, etc.)
  # This will depend on your specific UI implementation
  # You might look for specific classes or IDs that indicate navigation
  
  # Example checks (adjust based on your actual UI structure):
  testthat::expect_true(grepl("bslib-page-navbar", ui_html))
  testthat::expect_true(grepl("shiny-tab-input", ui_html)) 
})

testthat::test_that("Required CSS and JavaScript dependencies are included", {
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  ui_result <- ShinyImgVoteR::votingAppUI(cfg)
  ui_html <- as.character(ui_result)
  

  # Check for shinyjs (if used)
  testthat::expect_true(grepl("shinyjs", ui_html))
  
  # Check for any custom CSS/JS files
  testthat::expect_true(grepl("keydown", ui_html))
})

testthat::test_that("Module UIs are properly namespaced", {
  cfg <- ShinyImgVoteR::load_config(
    config_file_path = system.file(
      "shiny-app",
      "default_env",
      "config",
      "config.yaml",
      package = "ShinyImgVoteR"
    )
  )
  
  # Test individual module UIs if they're exported
  # This assumes you have separate UI functions for modules

  # Example for login module UI
  if (exists("loginUI")) {
    login_ui <- loginUI("test",  cfg)
    expect_s3_class(login_ui, "shiny.tag")
    
    login_html <- as.character(login_ui)
    testthat::expect_true(grepl("test-", login_html)) # Check for namespace
  }
})

# Integration test using shinytest2 (if available)
testthat::test_that("Full app integration test", {
  skip_if_not_installed("shinytest2")
  skip_if_not(interactive(), "Integration tests require interactive session")
  
  # This is a basic integration test
  # You would need to adjust this based on your app structure
  
  app <- AppDriver$new(
    app_dir = "../../", # Path to your app directory
    name = "variant-voting-app",
    height = 800,
    width = 1200
  )
  
  # Test initial load
  testthat::expect_true(app$get_js("document.readyState === 'complete'"))
  
  # Test that login panel is visible initially
  app$expect_text("Welcome to")
  
  # Clean up
  app$stop()
})
