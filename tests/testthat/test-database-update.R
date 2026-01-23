library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(ShinyImgVoteR)

testthat::test_that("update_annotations_table adds only new entries", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Create a temporary file with initial data
  initial_data <- data.frame(
    coordinates = c("chr1:1000", "chr2:2000", "chr3:3000"),
    REF = c("A", "G", "AT"),
    ALT = c("T", "C", "A"),
    path = c(
      "/test/images/path1.png",
      "/test/images/path2.png",
      "/test/images/path3.png"
    ),
    stringsAsFactors = FALSE
  )
  
  temp_file <- tempfile(fileext = ".tsv")
  write.table(
    initial_data,
    temp_file,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  
  # Get a connection
  conn <- pool::poolCheckout(test_pool)
  on.exit(pool::poolReturn(conn), add = TRUE)
  
  # Test: No new entries when file contains same data as DB
  new_count <- update_annotations_table(conn, temp_file)
  
  # chr1:1000 and chr3:3000 already exist, chr2:2000 has different REF/ALT
  # So we should have 1 new entry (chr2:2000 with G->C)
  testthat::expect_equal(new_count, 1)
  
  # Add a new entry to the file
  updated_data <- rbind(
    initial_data,
    data.frame(
      coordinates = "chr4:4000",
      REF = "C",
      ALT = "G",
      path = "/test/images/path4.png",
      stringsAsFactors = FALSE
    )
  )
  
  write.table(
    updated_data,
    temp_file,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  
  # Test: One new entry should be added
  new_count <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(new_count, 1)
  
  # Verify the new entry was added
  result <- DBI::dbGetQuery(
    test_pool,
    "SELECT * FROM annotations WHERE coordinates = 'chr4:4000'"
  )
  testthat::expect_equal(nrow(result), 1)
  testthat::expect_equal(result$REF, "C")
  testthat::expect_equal(result$ALT, "G")
  
  # Test: No new entries when called again with the same file
  new_count <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(new_count, 0)
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
  unlink(temp_file)
})

testthat::test_that("update_annotations_table handles duplicate coordinates with different REF/ALT", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Create a file with entries that have the same coordinates but different REF/ALT
  data_with_duplicates <- data.frame(
    coordinates = c("chr2:2000", "chr2:2000", "chr5:5000"),
    REF = c("T", "A", "G"),
    ALT = c("C", "G", "T"),
    path = c(
      "/test/images/path2c.png",
      "/test/images/path2d.png",
      "/test/images/path5.png"
    ),
    stringsAsFactors = FALSE
  )
  
  temp_file <- tempfile(fileext = ".tsv")
  write.table(
    data_with_duplicates,
    temp_file,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  
  # Get a connection
  conn <- pool::poolCheckout(test_pool)
  on.exit(pool::poolReturn(conn), add = TRUE)
  
  # The database already has chr2:2000 with (G->C) and (C->A)
  # So the new entries should be chr2:2000 with (T->C) and (A->G), plus chr5:5000
  new_count <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(new_count, 3)
  
  # Verify all entries with chr2:2000
  result <- DBI::dbGetQuery(
    test_pool,
    "SELECT REF, ALT FROM annotations WHERE coordinates = 'chr2:2000' ORDER BY REF"
  )
  testthat::expect_equal(nrow(result), 5) # Original 2 + 3 new
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
  unlink(temp_file)
})

testthat::test_that("update_annotations_table handles missing file gracefully", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  conn <- pool::poolCheckout(test_pool)
  on.exit(pool::poolReturn(conn), add = TRUE)
  
  # Test with non-existent file
  testthat::expect_error(
    update_annotations_table(conn, "/nonexistent/file.tsv"),
    "File not found"
  )
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
})

testthat::test_that("update_annotations_table processes paths correctly", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Create a file with full paths
  data_with_paths <- data.frame(
    coordinates = "chr6:6000",
    REF = "A",
    ALT = "C",
    path = "/full/path/to/images/test6.png",
    stringsAsFactors = FALSE
  )
  
  temp_file <- tempfile(fileext = ".tsv")
  write.table(
    data_with_paths,
    temp_file,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  
  # Get a connection
  conn <- pool::poolCheckout(test_pool)
  on.exit(pool::poolReturn(conn), add = TRUE)
  
  # Add the entry
  new_count <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(new_count, 1)
  
  # Verify the path was processed (parent directory removed)
  result <- DBI::dbGetQuery(
    test_pool,
    "SELECT path FROM annotations WHERE coordinates = 'chr6:6000'"
  )
  testthat::expect_equal(nrow(result), 1)
  # The path should have the parent directory removed
  testthat::expect_true(grepl("images/test6.png", result$path))
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
  unlink(temp_file)
})
