library(testthat)
library(DBI)
library(RSQLite)
library(digest)
library(yaml)

# Test init_user_data_structure function
test_that("init_user_data_structure creates correct directory structure", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_user_data_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Test directory creation
  user_data_dir <- init_user_data_structure(test_base)
  
  # Check that main user_data directory was created
  expected_user_data <- file.path(test_base, "user_data")
  expect_equal(user_data_dir, expected_user_data)
  expect_true(dir.exists(user_data_dir))
  
  # Check that all institute directories were created
  expected_institutes <- c(
    "CNAG", "DKFZ", "DNGC", "FPGMX", "Hartwig", "ISCIII", 
    "KU_Leuven", "Latvian_BRSC", "MOMA", "SciLifeLab",
    "Training_answers_not_saved", "Universidade_de_Aveiro",
    "University_of_Helsinki", "University_of_Oslo", 
    "University_of_Verona"
  )
  
  for (institute in expected_institutes) {
    institute_dir <- file.path(user_data_dir, institute)
    expect_true(dir.exists(institute_dir), 
                info = paste("Directory should exist:", institute_dir))
  }
  
  # Test that function handles existing directories gracefully
  user_data_dir2 <- init_user_data_structure(test_base)
  expect_equal(user_data_dir, user_data_dir2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_database function
test_that("init_external_database creates database correctly", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_db_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  dir.create(test_base, recursive = TRUE)
  
  # Test database creation with minimal structure (no data file)
  db_path <- init_external_database(test_base, "test_db.sqlite")
  
  expected_db_path <- file.path(test_base, "test_db.sqlite")
  expect_equal(db_path, expected_db_path)
  expect_true(file.exists(db_path))
  
  # Check database structure
  con <- dbConnect(RSQLite::SQLite(), db_path)
  tables <- dbListTables(con)
  expect_true("annotations" %in% tables)
  expect_true("sessionids" %in% tables)
  
  # Check annotations table structure
  annotations_info <- dbGetQuery(con, "PRAGMA table_info(annotations)")
  expected_columns <- c("coordinates", "REF", "ALT", "variant", "path", 
                       "vote_count_correct", "vote_count_no_variant", 
                       "vote_count_different_variant", "vote_count_not_sure", 
                       "vote_count_total")
  expect_true(all(expected_columns %in% annotations_info$name))
  
  # Check sessionids table structure
  sessionids_info <- dbGetQuery(con, "PRAGMA table_info(sessionids)")
  expected_sessionids_columns <- c("user", "sessionid", "login_time", "logout_time")
  expect_true(all(expected_sessionids_columns %in% sessionids_info$name))
  
  dbDisconnect(con)
  
  # Test that existing database is detected
  db_path2 <- init_external_database(test_base, "test_db.sqlite")
  expect_equal(db_path, db_path2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_database with data file
test_that("init_external_database works with data file", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_db_with_data")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  dir.create(test_base, recursive = TRUE)
  
  # Create a mock data file
  config_dir <- file.path(test_base, "config", "annotation_screenshots_paths")
  dir.create(config_dir, recursive = TRUE)
  
  data_file <- file.path(config_dir, "uro003_paths_mock.txt")
  test_data <- c(
    "chr1:1000\tA\tT\tA>T\t/vol/b1mg/test1.png",
    "chr2:2000\tG\tC\tG>C\t/vol/b1mg/test2.png",
    "chr3:3000\tC\tA\tC>A\t/vol/b1mg/test3.png"
  )
  writeLines(test_data, data_file)
  
  # Test database creation with data file
  db_path <- init_external_database(test_base, "test_with_data.sqlite")
  
  expect_true(file.exists(db_path))
  
  # Check that data was loaded
  con <- dbConnect(RSQLite::SQLite(), db_path)
  
  # Check that annotations were loaded
  row_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM annotations")
  expect_equal(row_count$count, 3)
  
  # Check that paths were modified correctly
  paths <- dbGetQuery(con, "SELECT path FROM annotations")
  expect_true(all(grepl("^images/", paths$path)))
  expect_false(any(grepl("/vol/b1mg/", paths$path)))
  
  # Check that vote count columns exist and are initialized
  vote_counts <- dbGetQuery(con, "SELECT vote_count_correct, vote_count_total FROM annotations LIMIT 1")
  expect_equal(vote_counts$vote_count_correct, 0)
  expect_equal(vote_counts$vote_count_total, 0)
  
  dbDisconnect(con)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test setup_external_environment function
test_that("setup_external_environment creates complete environment", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_complete_env")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Test complete environment setup
  result <- setup_external_environment(test_base)
  
  # Check return value structure
  expect_true(is.list(result))
  expect_true("user_data_dir" %in% names(result))
  expect_true("database_path" %in% names(result))
  expect_true("base_dir" %in% names(result))
  
  # Check that directories and files were created
  expect_true(dir.exists(result$user_data_dir))
  expect_true(file.exists(result$database_path))
  expect_equal(result$base_dir, test_base)
  
  # Check that user_data subdirectories exist
  expect_true(dir.exists(file.path(result$user_data_dir, "CNAG")))
  expect_true(dir.exists(file.path(result$user_data_dir, "DKFZ")))
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_config function
test_that("init_external_config creates configuration correctly", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_config_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Test config creation
  config_file <- init_external_config(test_base)

  expected_config_file <- file.path(test_base, "config", "config.yaml")
  expect_equal(config_file, expected_config_file)
  expect_true(file.exists(config_file))
  
  # Check that config directory was created
  config_dir <- file.path(test_base, "config")
  expect_true(dir.exists(config_dir))
  
  # Check that config file has content
  config_content <- yaml::read_yaml(config_file)
  expect_true(is.list(config_content))
  expect_true("application_title" %in% names(config_content))
  
  # Check that environment variable was set
  expect_equal(Sys.getenv("IMGVOTER_CONFIG_PATH"), config_file)
  
  # Test that existing config is detected
  config_file2 <- init_external_config(test_base)
  expect_equal(config_file, config_file2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
  Sys.unsetenv("IMGVOTER_CONFIG_PATH")
})

# Test file.symlink.exists function (internal function)
test_that("file.symlink.exists works correctly", {
  temp_dir <- tempdir()
  
  # Test with non-existent file
  non_existent <- file.path(temp_dir, "non_existent_file")
  expect_false(ShinyImgVoteR:::file.symlink.exists(non_existent))
  
  # Test with regular file
  regular_file <- file.path(temp_dir, "regular_file.txt")
  writeLines("test content", regular_file)
  expect_false(ShinyImgVoteR:::file.symlink.exists(regular_file))
  
  # Clean up
  unlink(regular_file)
})

# Test init_external_images function
test_that("init_external_images creates images directory", {
  app_dir <- get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_images_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Store original environment variable
  original_images_dir <- Sys.getenv("IMGVOTER_IMAGES_DIR")
  
  # Test images directory creation
  # suppressWarnings({
  images_dir <- init_external_images(test_base, "test_images")
  # })
  
  expected_images_dir <- file.path(test_base, "test_images")
  expect_equal(images_dir, expected_images_dir)
  expect_true(dir.exists(images_dir))
  expect_true(file.symlink.exists(file.path(app_dir, "www", "images")))
  # Check that symlink points to the correct directory
  expect_equal(
    normalizePath(file.path(app_dir, "www", "images")),
    normalizePath(images_dir)
  )
  
  # Restore original environment variable
  if (original_images_dir == "") {
    Sys.unsetenv("IMGVOTER_IMAGES_DIR")
  } else {
    Sys.setenv(IMGVOTER_IMAGES_DIR = original_images_dir)
  }

  # Clean up
  # delete the symlink if it exists
  symlink_path <- file.path(app_dir,"www","images")
  if (file.symlink.exists(symlink_path)) {
    unlink(symlink_path, recursive = TRUE)
  }
  unlink(test_base, recursive = TRUE)
})

# Test init_external_server_data function
test_that("init_external_server_data creates server data directory", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_server_data_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Test server_data directory creation
  server_data_dir <- init_external_server_data(test_base)
  
  expected_server_data_dir <- file.path(test_base, "server_data")
  expect_equal(server_data_dir, expected_server_data_dir)
  expect_true(dir.exists(server_data_dir))
  
  # Check that README was created
  readme_file <- file.path(server_data_dir, "README.md")
  expect_true(file.exists(readme_file))
  
  readme_content <- readLines(readme_file)
  expect_true(any(grepl("Server Data Directory", readme_content)))
  
  # Test that existing directory is handled correctly
  server_data_dir2 <- init_external_server_data(test_base)
  expect_equal(server_data_dir, server_data_dir2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_environment function
test_that("init_external_environment sets up complete environment with variables", {
  app_dir <- get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_full_env_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Store original environment variables
  original_env_vars <- list(
    IMGVOTER_USER_DATA_DIR = Sys.getenv("IMGVOTER_USER_DATA_DIR"),
    IMGVOTER_DATABASE_PATH = Sys.getenv("IMGVOTER_DATABASE_PATH"),
    IMGVOTER_CONFIG_PATH = Sys.getenv("IMGVOTER_CONFIG_PATH"),
    IMGVOTER_IMAGES_DIR = Sys.getenv("IMGVOTER_IMAGES_DIR"),
    IMGVOTER_SERVER_DATA_DIR = Sys.getenv("IMGVOTER_SERVER_DATA_DIR")
  )
  
  # Test complete environment initialization (suppress symlink warnings during testing)
  # suppressWarnings({
  result <- init_external_environment(test_base)
  # })
  
  # Check return value structure
  expect_true(is.list(result))
  expected_keys <- c("user_data_dir", "db_file", "config_file", "images_dir", "server_data_dir")
  expect_true(all(expected_keys %in% names(result)))
  
  # Check that all directories and files were created
  expect_true(dir.exists(result$user_data_dir))
  expect_true(file.exists(result$db_file))
  expect_true(file.exists(result$config_file))
  expect_true(dir.exists(result$images_dir))
  expect_true(dir.exists(result$server_data_dir))
  
  # Check that environment variables were set correctly
  expect_equal(Sys.getenv("IMGVOTER_USER_DATA_DIR"), result$user_data_dir)
  expect_equal(Sys.getenv("IMGVOTER_DATABASE_PATH"), result$db_file)
  expect_equal(Sys.getenv("IMGVOTER_CONFIG_PATH"), result$config_file)
  expect_equal(Sys.getenv("IMGVOTER_IMAGES_DIR"), result$images_dir)
  expect_equal(Sys.getenv("IMGVOTER_SERVER_DATA_DIR"), result$server_data_dir)
  
  # Check that user_data subdirectories exist
  expect_true(dir.exists(file.path(result$user_data_dir, "CNAG")))
  expect_true(dir.exists(file.path(result$user_data_dir, "Training_answers_not_saved")))
  
  # Restore original environment variables
  for (var_name in names(original_env_vars)) {
    if (original_env_vars[[var_name]] == "") {
      Sys.unsetenv(var_name)
    } else {
      Sys.setenv(setNames(original_env_vars[[var_name]], var_name))
    }
  }

  # Clean up
  # delete the symlink if it exists
  symlink_path <- file.path(app_dir,"www","images")
  if (file.symlink.exists(symlink_path)) {
    unlink(symlink_path, recursive = TRUE)
  }
  unlink(test_base, recursive = TRUE)
})
