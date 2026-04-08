library(testthat)
library(ShinyImgVoteR)
library(DBI)
library(RSQLite)
library(pool)

# Helper to create mock config
create_mock_config <- function() {
  list(
    radio_options = list(
      "Yes" = list(value = "yes", db_column = "vote_count_correct"),
      "Different variant" = list(
        value = "diff_var",
        db_column = "vote_count_different_variant"
      ),
      "Germline" = list(value = "germline", db_column = "vote_count_germline"),
      "None of the above" = list(
        value = "none_of_above",
        db_column = "vote_count_none_of_above"
      )
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
    option_db_column_map <- stats::setNames(
      vapply(
        create_mock_config()$radio_options,
        function(option) option$db_column,
        character(1)
      ),
      vapply(
        create_mock_config()$radio_options,
        function(option) option$value,
        character(1)
      )
    )
    vote_col <- option_db_column_map[[test_data$agreement[i]]]
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
  # Query each coordinate individually to avoid IN clause parameter issues
  for (coord in c("chr1:100", "chr2:200", "chr3:300")) {
    db_row <- DBI::dbGetQuery(
      db_pool,
      "SELECT coordinates, REF, ALT, vote_count_correct, vote_count_different_variant, vote_count_germline FROM annotations WHERE coordinates = ?",
      params = list(coord)
    )
    
    if (nrow(db_row) > 0) {
      # All vote counts should be 0 after reset
      testthat::expect_equal(db_row$vote_count_correct, 0)
      testthat::expect_equal(db_row$vote_count_different_variant, 0)
      testthat::expect_equal(db_row$vote_count_germline, 0)
    }
  }
  
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
  initial_total <- 0
  for (coord in c("chr1:100", "chr2:200")) {
    row <- DBI::dbGetQuery(
      db_pool,
      "SELECT coordinates, vote_count_correct FROM annotations WHERE coordinates = ?",
      params = list(coord)
    )
    if (nrow(row) > 0) {
      initial_total <- initial_total + row$vote_count_correct
    }
  }
  testthat::expect_equal(initial_total, 10)
  
  # Reset the annotations
  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())
  testthat::expect_true(result)
  
  # Verify vote counts were decremented by 1 for each vote
  final_total <- 0
  for (coord in c("chr1:100", "chr2:200")) {
    row <- DBI::dbGetQuery(
      db_pool,
      "SELECT coordinates, vote_count_correct FROM annotations WHERE coordinates = ?",
      params = list(coord)
    )
    if (nrow(row) > 0) {
      final_total <- final_total + row$vote_count_correct
    }
  }
  testthat::expect_equal(final_total, 8) # 10 - 2 = 8
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations resets vote_input_methods in user info JSON", {
  # Create temporary annotation file and user info JSON file
  temp_dir <- tempdir()
  
  # Create annotation file
  temp_file <- file.path(temp_dir, "testuser_annotations.tsv")
  user_annotations_colnames <- c(
    "coordinates", "REF", "ALT", "agreement", 
    "observation", "comment", "shinyauthr_session_id", 
    "time_till_vote_casted_in_seconds"
  )
  
  test_data <- data.frame(
    coordinates = c("chr1:100"),
    REF = c("A"),
    ALT = c("T"),
    agreement = c("yes"),
    observation = c("coverage"),
    comment = c("comment1"),
    shinyauthr_session_id = c("sess1"),
    time_till_vote_casted_in_seconds = c("10"),
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
  
  # Create corresponding user info JSON file
  user_info_file <- file.path(temp_dir, "testuser_info.json")
  user_info <- list(
    user_id = "testuser",
    voting_institute = "institute1",
    images_randomisation_seed = 12345,
    vote_input_methods = list(
      hotkey_count = 5,
      mouse_count = 3,
      unknown_count = 1
    )
  )
  
  jsonlite::write_json(
    user_info,
    user_info_file,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  
  # Create mock database
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  
  # Insert test variant into database
  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path) VALUES (?, ?, ?, ?)",
    params = list("chr1:100", "A", "T", "/test/path.png")
  )
  
  # Reset the annotations (should also reset vote_input_methods)
  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())
  
  # Check that reset was successful
  testthat::expect_true(result)
  
  # Read the updated user info JSON file
  updated_user_info <- jsonlite::read_json(user_info_file)
  
  # Verify vote_input_methods were reset to 0
  testthat::expect_equal(updated_user_info$vote_input_methods$hotkey_count, 0)
  testthat::expect_equal(updated_user_info$vote_input_methods$mouse_count, 0)
  testthat::expect_equal(updated_user_info$vote_input_methods$unknown_count, 0)
  
  # Verify other fields were preserved
  testthat::expect_equal(updated_user_info$user_id, "testuser")
  testthat::expect_equal(updated_user_info$voting_institute, "institute1")
  # Seed must have been updated (no longer the original 12345)
  testthat::expect_false(
    identical(updated_user_info$images_randomisation_seed, 12345),
    info = "images_randomisation_seed should be updated to a new seed on reset"
  )
  testthat::expect_true(
    is.numeric(updated_user_info$images_randomisation_seed),
    info = "images_randomisation_seed should be a numeric value"
  )
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(user_info_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations handles missing user info JSON gracefully", {
  # Create annotation file without corresponding info JSON
  temp_file <- tempfile(fileext = "_annotations.tsv")
  
  user_annotations_colnames <- c(
    "coordinates", "REF", "ALT", "agreement"
  )
  
  test_data <- data.frame(
    coordinates = c("chr1:100"),
    REF = c("A"),
    ALT = c("T"),
    agreement = c("yes"),
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
  
  # Insert test variant into database
  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path) VALUES (?, ?, ?, ?)",
    params = list("chr1:100", "A", "T", "/test/path.png")
  )
  
  # Reset the annotations (should succeed even without info.json file)
  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())
  
  # Should still succeed - missing info.json is not a fatal error
  testthat::expect_true(result)
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations syncs rows removed from the database", {
  # Scenario: "Update Database" was used to remove a variant (chr3:300) from the
  # database, but the user's annotation file still contains it. "Reset Annotations"
  # should drop the stale row from the user file so the two stay congruent.
  temp_file <- tempfile(fileext = ".tsv")

  user_annotations_colnames <- c(
    "coordinates", "REF", "ALT", "agreement",
    "observation", "comment", "shinyauthr_session_id",
    "time_till_vote_casted_in_seconds"
  )

  # User file has 3 rows
  test_data <- data.frame(
    coordinates = c("chr1:100", "chr2:200", "chr3:300"),
    REF = c("A", "T", "G"),
    ALT = c("T", "C", "A"),
    agreement = c("yes", "diff_var", "germline"),
    observation = c("", "", ""),
    comment = c("", "", ""),
    shinyauthr_session_id = c("sess1", "sess1", "sess1"),
    time_till_vote_casted_in_seconds = c("10", "20", "30"),
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

  # Database only has 2 of those 3 rows (chr3:300 was removed via Update Database)
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool

  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path, vote_count_correct) VALUES (?, ?, ?, ?, ?)",
    params = list("chr1:100", "A", "T", "/test/path.png", 1)
  )
  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path, vote_count_different_variant) VALUES (?, ?, ?, ?, ?)",
    params = list("chr2:200", "T", "C", "/test/path2.png", 1)
  )

  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())

  testthat::expect_true(result)

  reset_data <- read.table(
    temp_file,
    sep = "\t",
    header = TRUE,
    stringsAsFactors = FALSE,
    quote = "",
    comment.char = ""
  )

  # Only 2 rows should remain (chr3:300 was removed)
  testthat::expect_equal(nrow(reset_data), 2)
  testthat::expect_equal(sort(reset_data$coordinates), c("chr1:100", "chr2:200"))

  # All annotation columns should be cleared
  testthat::expect_true(all(reset_data$agreement == ""))

  # Vote counts for remaining rows should have been decremented
  for (coord in c("chr1:100", "chr2:200")) {
    row <- DBI::dbGetQuery(
      db_pool,
      "SELECT vote_count_correct, vote_count_different_variant FROM annotations WHERE coordinates = ?",
      params = list(coord)
    )
    if (nrow(row) > 0) {
      testthat::expect_equal(row$vote_count_correct + row$vote_count_different_variant, 0)
    }
  }

  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations appends rows added to the database", {
  # Scenario: "Update Database" added a new variant (chr4:400) to the database,
  # which is not yet in the user's annotation file. "Reset Annotations" should
  # append that row so the user file is congruent with the database.
  temp_file <- tempfile(fileext = ".tsv")

  user_annotations_colnames <- c(
    "coordinates", "REF", "ALT", "agreement",
    "observation", "comment", "shinyauthr_session_id",
    "time_till_vote_casted_in_seconds"
  )

  # User file has 2 rows
  test_data <- data.frame(
    coordinates = c("chr1:100", "chr2:200"),
    REF = c("A", "T"),
    ALT = c("T", "C"),
    agreement = c("yes", ""),
    observation = c("", ""),
    comment = c("", ""),
    shinyauthr_session_id = c("sess1", ""),
    time_till_vote_casted_in_seconds = c("10", ""),
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

  # Database has those 2 rows plus a newly added one (chr4:400)
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool

  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path, vote_count_correct) VALUES (?, ?, ?, ?, ?)",
    params = list("chr1:100", "A", "T", "/test/path.png", 1)
  )
  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path) VALUES (?, ?, ?, ?)",
    params = list("chr2:200", "T", "C", "/test/path2.png")
  )
  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path) VALUES (?, ?, ?, ?)",
    params = list("chr4:400", "G", "A", "/test/path4.png")
  )

  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())

  testthat::expect_true(result)

  reset_data <- read.table(
    temp_file,
    sep = "\t",
    header = TRUE,
    stringsAsFactors = FALSE,
    quote = "",
    comment.char = ""
  )

  # Should now have 3 rows (the original 2 + the new one from DB)
  testthat::expect_equal(nrow(reset_data), 3)
  testthat::expect_true("chr4:400" %in% reset_data$coordinates)

  # All annotation columns must be cleared
  testthat::expect_true(all(reset_data$agreement == ""))

  # The new row should have the correct coordinates/REF/ALT
  new_row <- reset_data[reset_data$coordinates == "chr4:400", ]
  testthat::expect_equal(new_row$REF, "G")
  testthat::expect_equal(new_row$ALT, "A")

  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})

testthat::test_that("reset_user_annotations handles congruent file and database unchanged", {
  # When file and database already match, behavior should be identical to before
  temp_file <- tempfile(fileext = ".tsv")

  user_annotations_colnames <- c(
    "coordinates", "REF", "ALT", "agreement",
    "observation", "comment", "shinyauthr_session_id",
    "time_till_vote_casted_in_seconds"
  )

  test_data <- data.frame(
    coordinates = c("chr1:100", "chr2:200"),
    REF = c("A", "T"),
    ALT = c("T", "C"),
    agreement = c("yes", "diff_var"),
    observation = c("", ""),
    comment = c("", ""),
    shinyauthr_session_id = c("sess1", "sess1"),
    time_till_vote_casted_in_seconds = c("10", "20"),
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

  mock_db <- create_mock_db()
  db_pool <- mock_db$pool

  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path, vote_count_correct) VALUES (?, ?, ?, ?, ?)",
    params = list("chr1:100", "A", "T", "/test/path.png", 1)
  )
  DBI::dbExecute(
    db_pool,
    "INSERT INTO annotations (coordinates, REF, ALT, path, vote_count_different_variant) VALUES (?, ?, ?, ?, ?)",
    params = list("chr2:200", "T", "C", "/test/path2.png", 1)
  )

  result <- reset_user_annotations(temp_file, user_annotations_colnames, db_pool, create_mock_config())

  testthat::expect_true(result)

  reset_data <- read.table(
    temp_file,
    sep = "\t",
    header = TRUE,
    stringsAsFactors = FALSE,
    quote = "",
    comment.char = ""
  )

  # Row count unchanged
  testthat::expect_equal(nrow(reset_data), 2)
  # Coordinates preserved
  testthat::expect_equal(sort(reset_data$coordinates), c("chr1:100", "chr2:200"))
  # All annotation columns cleared
  testthat::expect_true(all(reset_data$agreement == ""))

  pool::poolClose(db_pool)
  unlink(temp_file)
  unlink(mock_db$file)
})
