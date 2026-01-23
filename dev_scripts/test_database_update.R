#!/usr/bin/env Rscript
# Manual test script for database update functionality
# This script demonstrates how to test the file watcher and database update

library(ShinyImgVoteR)

cat("=== Manual Test for Database Update Functionality ===\n\n")

cat("Instructions:\n")
cat("1. Start the Shiny app using: make run\n")
cat("2. While the app is running, modify the to_be_voted_images_file\n")
cat("3. Add new rows to: ./app_env/images/to_be_voted_images.tsv\n")
cat("4. Wait approximately 5 seconds\n")
cat("5. You should see a notification in the app saying 'Database updated: X new entries added'\n")
cat("6. The new entries will be available for voting\n\n")

cat("Example of adding a new entry:\n")
cat("chr7:7000\tA\tG\t./app_env/images/pngs/example_new.png\n\n")

cat("Testing the update_annotations_table function directly:\n\n")

# Create a temporary database for testing
temp_db <- tempfile(fileext = ".sqlite")
temp_file <- tempfile(fileext = ".tsv")

cat("Creating test database at:", temp_db, "\n")
cat("Creating test TSV file at:", temp_file, "\n\n")

# Create a simple test database
conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = temp_db)

# Create annotations table
DBI::dbExecute(
  conn,
  "CREATE TABLE annotations (
    coordinates TEXT,
    REF TEXT,
    ALT TEXT,
    path TEXT,
    vote_count_correct INTEGER DEFAULT 0,
    vote_count_different_variant INTEGER DEFAULT 0,
    vote_count_germline INTEGER DEFAULT 0,
    vote_count_none_of_above INTEGER DEFAULT 0,
    vote_count_total INTEGER DEFAULT 0
  )"
)

# Add initial data
DBI::dbExecute(
  conn,
  "INSERT INTO annotations (coordinates, REF, ALT, path) VALUES (?, ?, ?, ?)",
  params = list("chr1:1000", "A", "T", "images/test1.png")
)

cat("Initial database state:\n")
print(DBI::dbGetQuery(conn, "SELECT * FROM annotations"))
cat("\n")

# Create test TSV file with one existing and one new entry
test_data <- data.frame(
  coordinates = c("chr1:1000", "chr2:2000"),
  REF = c("A", "G"),
  ALT = c("T", "C"),
  path = c("./test/images/test1.png", "./test/images/test2.png"),
  stringsAsFactors = FALSE
)

write.table(
  test_data,
  temp_file,
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

cat("Test TSV file contents:\n")
print(read.table(temp_file, header = TRUE, stringsAsFactors = FALSE))
cat("\n")

# Call the update function (this will be available after sourcing db_utils.R)
cat("Calling update_annotations_table()...\n")
tryCatch({
  # Source the function if running outside of package
  source(system.file("shiny-app", "../R/db_utils.R", package = "ShinyImgVoteR"))
  
  update_summary <- update_annotations_table(conn, temp_file)
  cat(
    "Update summary:",
    update_summary$added, "added,",
    update_summary$updated, "updated,",
    update_summary$removed, "removed\n\n"
  )
  
  cat("Database state after update:\n")
  print(DBI::dbGetQuery(conn, "SELECT * FROM annotations"))
  
}, error = function(e) {
  cat("Error:", conditionMessage(e), "\n")
  cat("Note: This script should be run after installing the package with 'make install'\n")
})

# Cleanup
DBI::dbDisconnect(conn)
unlink(temp_db)
unlink(temp_file)

cat("\n=== Test Complete ===\n")
