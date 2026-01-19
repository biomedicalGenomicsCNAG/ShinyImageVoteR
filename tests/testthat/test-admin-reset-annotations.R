library(testthat)
library(ShinyImgVoteR)
library(DBI)
library(RSQLite)
library(pool)

# Helper to create mock config
create_mock_config <- function() {
  list(
    vote2dbcolumn_map = list(
      'yes' = 'vote_count_correct',
      'diff_var' = 'vote_count_different_variant',
      'germline' = 'vote_count_germline',
      'none_of_above' = 'vote_count_none_of_above'
    )
  )
}

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
  
  # Create mock database
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  
  # Insert test variants into database
  for (i in seq_len(nrow(test_data))) {
    DBI::dbExecute(
      db_pool,
      "INSERT INTO annotations (coordinates, REF, ALT, path) VALUES (?, ?, ?, ?)",
      params = list(test_data$coordinates[i], test_data$REF[i], test_data$ALT[i], "/test/path.png")
    )
    
    # Simulate that votes were cast
    vote_col <- create_mock_config()$vote2dbcolumn_map[[test_data$agreement[i]]]
    if (!is.null(vote_col)) {
      DBI::dbExecute(
        db_pool,
        paste0("UPDATE annotations SET ", vote_col, " = 1 WHERE coordinates = ? AND REF = ? AND ALT = ?"),
        params = list(test_data$coordinates[i], test_data$REF[i], test_data$ALT[i])
      )
    }
  }
  
  # Reset the annotations
  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())
  
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
  
  # Verify database vote counts were decremented
  db_data <- DBI::dbGetQuery(
    db_pool,
    "SELECT coordinates, REF, ALT, vote_count_correct, vote_count_different_variant, vote_count_germline FROM annotations WHERE coordinates IN (?, ?, ?)",
    params = list("chr1:100", "chr2:200", "chr3:300")
  )
  
  # All vote counts should be 0 after reset
  testthat::expect_equal(sum(db_data$vote_count_correct), 0)
  testthat::expect_equal(sum(db_data$vote_count_different_variant), 0)
  testthat::expect_equal(sum(db_data$vote_count_germline), 0)
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations handles missing file", {
  # Create mock database and config
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  mock_cfg <- create_mock_config()
  
  # Test with non-existent file
  result <- reset_user_annotations(
    "/tmp/nonexistent_file.tsv",
    c("coordinates", "REF", "ALT", "agreement"),
    db_pool,
    mock_cfg
  )
  
  testthat::expect_false(result)
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(mock_db$file)
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
  
  # Create mock database and config
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  mock_cfg <- create_mock_config()
  
  result <- reset_user_annotations(
    temp_file,
    c("coordinates", "REF", "ALT", "agreement"),
    db_pool,
    mock_cfg
  )
  
  testthat::expect_false(result)
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations handles NULL parameters", {
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
  
  # Create mock database and config
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  mock_cfg <- create_mock_config()
  
  # Test NULL column names
  result <- reset_user_annotations(temp_file, NULL, db_pool, mock_cfg)
  testthat::expect_false(result)
  
  # Test NULL db_pool
  result <- reset_user_annotations(temp_file, c("coordinates", "REF", "ALT"), NULL, mock_cfg)
  testthat::expect_false(result)
  
  # Test NULL cfg
  result <- reset_user_annotations(temp_file, c("coordinates", "REF", "ALT"), db_pool, NULL)
  testthat::expect_false(result)
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations correctly decrements vote counts", {
  # Create a temporary annotation file with votes
  temp_file <- tempfile(fileext = ".tsv")
  
  user_annotations_colnames <- c(
    "coordinates", "REF", "ALT", "agreement", 
    "observation", "comment", "shinyauthr_session_id", 
    "time_till_vote_casted_in_seconds"
  )
  
  # Create data with specific votes
  test_data <- data.frame(
    coordinates = c("chr1:100", "chr2:200"),
    REF = c("A", "T"),
    ALT = c("T", "C"),
    agreement = c("yes", "yes"),
    observation = c("", ""),
    comment = c("", ""),
    shinyauthr_session_id = c("sess1", "sess1"),
    time_till_vote_casted_in_seconds = c("10", "15"),
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
  
  # Create mock database
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  
  # Insert test variants and set initial vote counts
  for (i in seq_len(nrow(test_data))) {
    DBI::dbExecute(
      db_pool,
      "INSERT INTO annotations (coordinates, REF, ALT, path, vote_count_correct) VALUES (?, ?, ?, ?, ?)",
      params = list(test_data$coordinates[i], test_data$REF[i], test_data$ALT[i], "/test/path.png", 5)
    )
  }
  
  # Get initial vote counts
  initial_counts <- DBI::dbGetQuery(
    db_pool,
    "SELECT coordinates, vote_count_correct FROM annotations WHERE coordinates IN (?, ?)",
    params = list("chr1:100", "chr2:200")
  )
  testthat::expect_equal(sum(initial_counts$vote_count_correct), 10)
  
  # Reset the annotations
  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())
  testthat::expect_true(result)
  
  # Verify vote counts were decremented by 1 for each vote
  final_counts <- DBI::dbGetQuery(
    db_pool,
    "SELECT coordinates, vote_count_correct FROM annotations WHERE coordinates IN (?, ?)",
    params = list("chr1:100", "chr2:200")
  )
  testthat::expect_equal(sum(final_counts$vote_count_correct), 8) # 10 - 2 = 8
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

