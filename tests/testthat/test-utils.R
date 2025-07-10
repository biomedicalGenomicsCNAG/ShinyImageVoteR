library(testthat)
library(jsonlite)
library(digest)

test_that("JSON file operations work correctly", {
  # Test user info JSON creation and reading
  temp_file <- tempfile(fileext = ".json")
  
  user_info <- list(
    user_id = "test_user",
    voting_institute = "CNAG",
    images_randomisation_seed = 12345
  )
  
  # Write JSON
  write_json(user_info, temp_file, auto_unbox = TRUE, pretty = TRUE)
  expect_true(file.exists(temp_file))
  
  # Read JSON
  loaded_info <- read_json(temp_file)
  expect_equal(loaded_info$user_id, user_info$user_id)
  expect_equal(loaded_info$voting_institute, user_info$voting_institute)
  expect_equal(loaded_info$images_randomisation_seed, user_info$images_randomisation_seed)
  
  # Clean up
  unlink(temp_file)
})

test_that("TSV file operations work correctly", {
  # Test annotations TSV creation and reading
  temp_file <- tempfile(fileext = ".tsv")
  
  # Create test data frame
  test_data <- data.frame(
    coordinates = c("chr1:1000", "chr2:2000", "chr3:3000"),
    agreement = c("", "", ""),
    alternative_vartype = c("", "", ""),
    observation = c("", "", ""),
    comment = c("", "", ""),
    shinyauthr_session_id = c("", "", ""),
    time_till_vote_casted_in_seconds = c("", "", ""),
    stringsAsFactors = FALSE
  )
  
  # Write TSV
  write.table(
    test_data,
    file = temp_file,
    sep = "\t",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  expect_true(file.exists(temp_file))
  
  # Read TSV
  loaded_data <- read.table(temp_file, sep = "\t", header = TRUE, stringsAsFactors = FALSE)
  expect_equal(nrow(loaded_data), 3)
  expect_equal(loaded_data$coordinates, test_data$coordinates)
  expect_equal(names(loaded_data), names(test_data))
  
  # Clean up
  unlink(temp_file)
})

test_that("Directory utilities work correctly", {
  # Test directory creation with spaces
  temp_base <- tempdir()
  test_institutes <- c("Test Institute", "Another Test Org")
  
  for (institute in test_institutes) {
    # Replace spaces with underscores (like in the app)
    institute_clean <- gsub(" ", "_", institute)
    test_dir <- file.path(temp_base, "user_data", institute_clean)
    dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)
    
    expect_true(dir.exists(test_dir))
  }
  
  # Check that directories were created with underscores
  expect_true(dir.exists(file.path(temp_base, "user_data", "Test_Institute")))
  expect_true(dir.exists(file.path(temp_base, "user_data", "Another_Test_Org")))
  
  # Clean up
  unlink(file.path(temp_base, "user_data"), recursive = TRUE)
})

test_that("Hash and seed generation utilities work", {
  # Test digest consistency
  input_text <- "test_string_123"
  
  hash1 <- digest(input_text, algo = "crc32")
  hash2 <- digest(input_text, algo = "crc32")
  
  expect_equal(hash1, hash2)
  expect_true(nchar(hash1) > 0)
  
  # Test seed conversion
  seed1 <- strtoi(substr(hash1, 1, 7), base = 16)
  seed2 <- strtoi(substr(hash2, 1, 7), base = 16)
  
  expect_equal(seed1, seed2)
  expect_true(is.numeric(seed1))
  expect_true(seed1 > 0)
})

test_that("File path utilities work correctly", {
  # Test file path construction
  user_id <- "test_user"
  voting_institute <- "CNAG"
  
  user_dir <- file.path("user_data", voting_institute, user_id)
  info_file <- file.path(user_dir, paste0(user_id, "_info.json"))
  annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.tsv"))
  
  # Check path construction
  expect_true(grepl("user_data", user_dir))
  expect_true(grepl("CNAG", user_dir))
  expect_true(grepl("test_user", user_dir))
  
  expect_true(grepl("_info.json", info_file))
  expect_true(grepl("_annotations.tsv", annotations_file))
})

test_that("Time utilities work correctly", {
  # Test time-based operations
  start_time <- Sys.time()
  Sys.sleep(0.1)  # Small delay
  end_time <- Sys.time()
  
  time_diff <- as.numeric(difftime(end_time, start_time, units = "secs"))
  expect_true(time_diff >= 0.1)
  expect_true(time_diff < 1.0)  # Should be much less than 1 second
})

test_that("String manipulation utilities work", {
  # Test space replacement (used for institute names)
  test_string <- "Test Institute Name"
  cleaned_string <- gsub(" ", "_", test_string)
  
  expect_equal(cleaned_string, "Test_Institute_Name")
  expect_false(grepl(" ", cleaned_string))
  
  # Test paste operations
  user_id <- "test_user"
  timestamp <- 1609459200
  combined <- paste0(user_id, timestamp)
  
  expect_equal(combined, "test_user1609459200")
  expect_true(nchar(combined) > nchar(user_id))
})

test_that("Randomization utilities work correctly", {
  # Test reproducible randomization
  test_vector <- c("item1", "item2", "item3", "item4", "item5")
  
  # Set seed and randomize
  set.seed(12345)
  randomized1 <- sample(test_vector, length(test_vector), replace = FALSE)
  
  # Reset seed and randomize again
  set.seed(12345)
  randomized2 <- sample(test_vector, length(test_vector), replace = FALSE)
  
  # Should be identical
  expect_equal(randomized1, randomized2)
  
  # Should contain all original elements
  expect_true(all(test_vector %in% randomized1))
  expect_equal(length(randomized1), length(test_vector))
})
