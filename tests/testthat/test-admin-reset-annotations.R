library(testthat)
library(ShinyImgVoteR)

testthat::test_that("reset_user_annotations keeps headers and coordinates", {
  # Create a temporary annotation file with test data
  temp_file <- tempfile(fileext = ".tsv")
  
  # Define column names as per config
  user_annotations_colnames <- c(
    "coordinates", "REF", "ALT", "agreement", 
    "observation", "comment", "shinyauthr_session_id", 
    "time_till_vote_casted_in_seconds"
  )
  
  # Create sample data
  test_data <- data.frame(
    coordinates = c("chr1:100", "chr2:200", "chr3:300"),
    REF = c("A", "T", "G"),
    ALT = c("T", "C", "A"),
    agreement = c("yes", "diff_var", "germline"),
    observation = c("coverage", "alignment", "complex"),
    comment = c("comment1", "comment2", "comment3"),
    shinyauthr_session_id = c("sess1", "sess2", "sess3"),
    time_till_vote_casted_in_seconds = c("10", "20", "30"),
    stringsAsFactors = FALSE
  )
  
  # Write test data to file
  write.table(
    test_data,
    file = temp_file,
    sep = "\t",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  
  # Reset the annotations
  result <- reset_user_annotations(temp_file, user_annotations_colnames)
  
  # Check that reset was successful
  testthat::expect_true(result)
  
  # Read the reset file
  reset_data <- read.table(
    temp_file,
    sep = "\t",
    header = TRUE,
    stringsAsFactors = FALSE,
    quote = "",
    comment.char = ""
  )
  
  # Verify column names are preserved
  testthat::expect_equal(colnames(reset_data), user_annotations_colnames)
  
  # Verify coordinates, REF, ALT are preserved
  testthat::expect_equal(reset_data$coordinates, c("chr1:100", "chr2:200", "chr3:300"))
  testthat::expect_equal(reset_data$REF, c("A", "T", "G"))
  testthat::expect_equal(reset_data$ALT, c("T", "C", "A"))
  
  # Verify other columns are empty
  testthat::expect_equal(reset_data$agreement, c("", "", ""))
  testthat::expect_equal(reset_data$observation, c("", "", ""))
  testthat::expect_equal(reset_data$comment, c("", "", ""))
  testthat::expect_equal(reset_data$shinyauthr_session_id, c("", "", ""))
  testthat::expect_equal(reset_data$time_till_vote_casted_in_seconds, c("", "", ""))
  
  # Clean up
  unlink(temp_file)
})

testthat::test_that("reset_user_annotations handles missing file", {
  # Test with non-existent file
  result <- reset_user_annotations(
    "/tmp/nonexistent_file.tsv",
    c("coordinates", "REF", "ALT", "agreement")
  )
  
  testthat::expect_false(result)
})

testthat::test_that("reset_user_annotations handles invalid columns", {
  # Create a temporary file without required columns
  temp_file <- tempfile(fileext = ".tsv")
  
  test_data <- data.frame(
    wrong_col = c("val1", "val2"),
    another_col = c("val3", "val4"),
    stringsAsFactors = FALSE
  )
  
  write.table(
    test_data,
    file = temp_file,
    sep = "\t",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  
  result <- reset_user_annotations(
    temp_file,
    c("coordinates", "REF", "ALT", "agreement")
  )
  
  testthat::expect_false(result)
  
  # Clean up
  unlink(temp_file)
})

testthat::test_that("reset_user_annotations handles NULL column names", {
  temp_file <- tempfile(fileext = ".tsv")
  
  test_data <- data.frame(
    coordinates = c("chr1:100"),
    REF = c("A"),
    ALT = c("T"),
    stringsAsFactors = FALSE
  )
  
  write.table(
    test_data,
    file = temp_file,
    sep = "\t",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  
  result <- reset_user_annotations(temp_file, NULL)
  
  testthat::expect_false(result)
  
  # Clean up
  unlink(temp_file)
})
