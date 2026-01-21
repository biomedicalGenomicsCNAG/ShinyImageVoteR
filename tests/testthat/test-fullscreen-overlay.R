library(testthat)
library(shiny)
library(ShinyImgVoteR)

testthat::test_that("Fullscreen overlay JavaScript is included in voting UI", {
  cfg <- ShinyImgVoteR::load_config()
  ui <- ShinyImgVoteR::votingUI("test", cfg)
  ui_html <- as.character(ui)
  
  # Check that fullscreen-overlay.js is included
  testthat::expect_true(
    grepl("fullscreen-overlay\\.js", ui_html),
    info = "fullscreen-overlay.js should be included in the voting UI"
  )
})

testthat::test_that("Voting styles CSS contains fullscreen classes", {
  css_file <- system.file(
    "shiny-app/www/voting-styles.css",
    package = "ShinyImgVoteR"
  )
  
  # Skip if the file doesn't exist (e.g., during development)
  skip_if_not(file.exists(css_file), "CSS file not found")
  
  css_content <- readLines(css_file, warn = FALSE)
  css_text <- paste(css_content, collapse = "\n")
  
  # Check for fullscreen overlay styles
  testthat::expect_true(
    grepl("\\.fullscreen-overlay", css_text),
    info = "CSS should contain .fullscreen-overlay class"
  )
  
  testthat::expect_true(
    grepl("\\.fullscreen-btn", css_text),
    info = "CSS should contain .fullscreen-btn class"
  )
  
  testthat::expect_true(
    grepl("\\.fullscreen-close-btn", css_text),
    info = "CSS should contain .fullscreen-close-btn class"
  )
  
  testthat::expect_true(
    grepl("\\.fullscreen-image", css_text),
    info = "CSS should contain .fullscreen-image class"
  )
})

testthat::test_that("Fullscreen overlay JavaScript file exists", {
  js_file <- system.file(
    "shiny-app/www/js/fullscreen-overlay.js",
    package = "ShinyImgVoteR"
  )
  
  # Skip if the file doesn't exist (e.g., during development)
  skip_if_not(file.exists(js_file), "JavaScript file not found")
  
  js_content <- readLines(js_file, warn = FALSE)
  js_text <- paste(js_content, collapse = "\n")
  
  # Check for key functions
  testthat::expect_true(
    grepl("function openOverlay", js_text) || grepl("openOverlay.*=.*function", js_text),
    info = "JavaScript should contain openOverlay function"
  )
  
  testthat::expect_true(
    grepl("function closeOverlay", js_text) || grepl("closeOverlay.*=.*function", js_text),
    info = "JavaScript should contain closeOverlay function"
  )
  
  # Check for event handlers
  testthat::expect_true(
    grepl("dblclick", js_text),
    info = "JavaScript should handle double-click events"
  )
  
  testthat::expect_true(
    grepl("Escape", js_text),
    info = "JavaScript should handle Escape key"
  )
  
  # Check for fullscreen button creation
  testthat::expect_true(
    grepl("fullscreen-btn", js_text),
    info = "JavaScript should create fullscreen button"
  )
})

testthat::test_that("votingUI maintains existing structure with fullscreen support", {
  cfg <- ShinyImgVoteR::load_config()
  ui <- ShinyImgVoteR::votingUI("voting", cfg)
  ui_html <- as.character(ui)
  
  # Verify all JavaScript files are included
  required_js <- c("panzoom.min.js", "init-panzoom.js", "hotkeys.js", "fullscreen-overlay.js")
  
  for (js_file in required_js) {
    testthat::expect_true(
      grepl(js_file, ui_html),
      info = paste(js_file, "should be included in voting UI")
    )
  }
  
  # Verify existing functionality is not broken
  testthat::expect_true(
    grepl("data-panzoom-container", ui_html) || grepl("voting_image_container", ui_html),
    info = "Image container should still be present"
  )
})
