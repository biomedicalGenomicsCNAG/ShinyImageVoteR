library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(ShinyImgVoteR)

create_dummy_files <- function(paths) {
  dirs <- unique(dirname(paths))
  for (d in dirs) {
    if (!dir.exists(d)) {
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
    }
  }
  for (p in paths) {
    if (!file.exists(p)) {
      file.create(p)
    }
  }
}

testthat::test_that("update_annotations_table adds only new entries", {
  # Create mock database
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool
  
  # Create a temporary file with initial data
  img_dir <- tempfile("images")
  initial_paths <- file.path(img_dir, c("path1.png", "path2.png", "path3.png"))
  create_dummy_files(initial_paths)
  initial_data <- data.frame(
    coordinates = c("chr1:1000", "chr2:2000", "chr3:3000"),
    REF = c("A", "G", "AT"),
    ALT = c("T", "C", "A"),
    path = initial_paths,
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
  update_summary <- update_annotations_table(conn, temp_file)
  
  # chr1:1000 and chr3:3000 already exist, chr2:2000 has different REF/ALT
  # So we should have 1 new entry (chr2:2000 with G->C)
  testthat::expect_equal(update_summary$added, 1)
  testthat::expect_equal(update_summary$updated, 0)
  testthat::expect_equal(update_summary$removed, 0)
  
  # Add a new entry to the file
  new_path <- file.path(img_dir, "path4.png")
  create_dummy_files(new_path)
  updated_data <- rbind(
    initial_data,
    data.frame(
      coordinates = "chr4:4000",
      REF = "C",
      ALT = "G",
      path = new_path,
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
  update_summary <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(update_summary$added, 1)
  testthat::expect_equal(update_summary$updated, 0)
  testthat::expect_equal(update_summary$removed, 0)
  
  # Verify the new entry was added
  result <- DBI::dbGetQuery(
    test_pool,
    "SELECT * FROM annotations WHERE coordinates = 'chr4:4000'"
  )
  testthat::expect_equal(nrow(result), 1)
  testthat::expect_equal(result$REF, "C")
  testthat::expect_equal(result$ALT, "G")
  
  # Test: No new entries when called again with the same file
  update_summary <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(update_summary$added, 0)
  testthat::expect_equal(update_summary$updated, 0)
  testthat::expect_equal(update_summary$removed, 0)
  
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
  img_dir <- tempfile("images")
  dup_paths <- file.path(img_dir, c("path2c.png", "path2d.png", "path5.png"))
  create_dummy_files(dup_paths)
  data_with_duplicates <- data.frame(
    coordinates = c("chr2:2000", "chr2:2000", "chr5:5000"),
    REF = c("T", "A", "G"),
    ALT = c("C", "G", "T"),
    path = dup_paths,
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
  update_summary <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(update_summary$added, 3)
  testthat::expect_equal(update_summary$updated, 0)
  testthat::expect_equal(update_summary$removed, 0)
  
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
  img_dir <- tempfile("images")
  nested_dir <- file.path(img_dir, "pngs")
  path6 <- file.path(nested_dir, "test6.png")
  create_dummy_files(path6)
  data_with_paths <- data.frame(
    coordinates = "chr6:6000",
    REF = "A",
    ALT = "C",
    path = path6,
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
  update_summary <- update_annotations_table(conn, temp_file)
  testthat::expect_equal(update_summary$added, 1)
  testthat::expect_equal(update_summary$updated, 0)
  testthat::expect_equal(update_summary$removed, 0)
  
  # Verify the path was processed (parent directory removed)
  result <- DBI::dbGetQuery(
    test_pool,
    "SELECT path FROM annotations WHERE coordinates = 'chr6:6000'"
  )
  testthat::expect_equal(nrow(result), 1)
  # The path should have the parent directory removed
  testthat::expect_true(grepl("pngs/test6.png", result$path))
  
  # Clean up
  poolClose(test_pool)
  unlink(mock_db$file)
  unlink(temp_file)
})

testthat::test_that("update_annotations_table detects updates and removals", {
  mock_db <- create_mock_db()
  test_pool <- mock_db$pool

  # Modify path for existing entry and remove one entry
  img_dir <- tempfile("images")
  updated_paths <- file.path(img_dir, c("updated_path1.png", "path2.png", "path2b.png"))
  create_dummy_files(updated_paths)
  updated_data <- data.frame(
    coordinates = c("chr1:1000", "chr2:2000", "chr2:2000"),
    REF = c("A", "G", "C"),
    ALT = c("T", "C", "A"),
    path = updated_paths,
    stringsAsFactors = FALSE
  )

  temp_file <- tempfile(fileext = ".tsv")
  write.table(
    updated_data,
    temp_file,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )

  conn <- pool::poolCheckout(test_pool)
  on.exit(pool::poolReturn(conn), add = TRUE)

  update_summary <- update_annotations_table(conn, temp_file)

  # One path updated (chr1:1000) and one row removed (chr3:3000)
  testthat::expect_equal(update_summary$added, 0)
  testthat::expect_equal(update_summary$updated, 1)
  testthat::expect_equal(update_summary$removed, 1)

  updated_row <- DBI::dbGetQuery(
    test_pool,
    "SELECT path FROM annotations WHERE coordinates = 'chr1:1000' AND REF = 'A' AND ALT = 'T'"
  )
  testthat::expect_true(grepl("updated_path1.png", updated_row$path))

  removed_row <- DBI::dbGetQuery(
    test_pool,
    "SELECT * FROM annotations WHERE coordinates = 'chr3:3000' AND REF = 'AT' AND ALT = 'A'"
  )
  testthat::expect_equal(nrow(removed_row), 0)

  poolClose(test_pool)
  unlink(mock_db$file)
  unlink(temp_file)
})
