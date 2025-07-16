library(testthat)
library(DBI)
library(RSQLite)
library(digest)
library(yaml)

# Test init_user_data_structure function
testthat::test_that("init_user_data_structure creates correct directory structure", {
  app_dir <- ShinyImgVoteR::get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_user_data_init")
  config_dir <- file.path(app_dir,"config")

  Sys.setenv("IMGVOTER_CONFIG_DIR" = config_dir)
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # browser()
  # debugonce(ShinyImgVoteR::init_user_data_structure)
  
  # Test directory creation
  user_data_dir <- ShinyImgVoteR::init_user_data_structure(test_base)
  
  # Check that main user_data directory was created
  expected_user_data <- file.path(test_base, "user_data")
  testthat::expect_equal(user_data_dir, expected_user_data)
  testthat::expect_true(dir.exists(user_data_dir))
  
  # Check that all institute directories were created
  expected_institutes <- c(
    "training_answers_not_saved","institute1"
  )
  
  for (institute in expected_institutes) {
    institute_dir <- file.path(user_data_dir, institute)
    testthat::expect_true(
      dir.exists(institute_dir), 
      info = paste("Directory should exist:", institute_dir)
    )
  }
  
  # Test that function handles existing directories gracefully
  user_data_dir2 <- ShinyImgVoteR::init_user_data_structure(test_base)
  testthat::expect_equal(user_data_dir, user_data_dir2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_database function
testthat::test_that("init_external_database creates database correctly", {
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
  testthat::expect_equal(db_path, expected_db_path)
  testthat::expect_true(file.exists(db_path))
  
  # Check database structure
  con <- dbConnect(RSQLite::SQLite(), db_path)
  tables <- dbListTables(con)
  testthat::expect_true("annotations" %in% tables)
  testthat::expect_true("sessionids" %in% tables)
  
  # Check annotations table structure
  annotations_info <- dbGetQuery(con, "PRAGMA table_info(annotations)")
  expected_columns <- c("coordinates", "REF", "ALT", "variant", "path", 
                       "vote_count_correct", "vote_count_no_variant", 
                       "vote_count_different_variant", "vote_count_not_sure", 
                       "vote_count_total")
  testthat::expect_true(all(expected_columns %in% annotations_info$name))
  
  # Check sessionids table structure
  sessionids_info <- dbGetQuery(con, "PRAGMA table_info(sessionids)")
  expected_sessionids_columns <- c("user", "sessionid", "login_time", "logout_time")
  testthat::expect_true(all(expected_sessionids_columns %in% sessionids_info$name))
  
  dbDisconnect(con)
  
  # Test that existing database is detected
  db_path2 <- init_external_database(test_base, "test_db.sqlite")
  testthat::expect_equal(db_path, db_path2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_database with data file
testthat::test_that("init_external_database works with data file", {
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
  
  testthat::expect_true(file.exists(db_path))
  
  # Check that data was loaded
  con <- dbConnect(RSQLite::SQLite(), db_path)
  
  # Check that annotations were loaded
  row_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM annotations")
  testthat::expect_equal(row_count$count, 3)
  
  # Check that paths were modified correctly
  paths <- dbGetQuery(con, "SELECT path FROM annotations")
  testthat::expect_true(all(grepl("^images/", paths$path)))
  expect_false(any(grepl("/vol/b1mg/", paths$path)))
  
  # Check that vote count columns exist and are initialized
  vote_counts <- dbGetQuery(con, "SELECT vote_count_correct, vote_count_total FROM annotations LIMIT 1")
  testthat::expect_equal(vote_counts$vote_count_correct, 0)
  testthat::expect_equal(vote_counts$vote_count_total, 0)
  
  dbDisconnect(con)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test setup_external_environment function
testthat::test_that("setup_external_environment creates complete environment", {
  app_dir <- ShinyImgVoteR::get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_complete_env")
  config_dir <- file.path(app_dir,"config")

  Sys.setenv("IMGVOTER_CONFIG_DIR" = config_dir)
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Test complete environment setup
  result <- ShinyImgVoteR::setup_external_environment(test_base)

  # write result to file for debugging
  writeLines(
    paste("Result:", toString(result)), 
    file.path("/home/ivo/projects/bioinfo/cnag/repos/B1MG-variant-voting/", "setup_external_environment_result.txt")
  )

  # browser()
  
  # Check return value structure
  testthat::expect_true(is.list(result))
  testthat::expect_true("user_data_dir" %in% names(result))
  testthat::expect_true("database_path" %in% names(result))
  testthat::expect_true("base_dir" %in% names(result))
  
  # Check that directories and files were created
  testthat::expect_true(dir.exists(result$user_data_dir))
  testthat::expect_true(file.exists(result$database_path))
  testthat::expect_equal(result$base_dir, test_base)
  
  # Check that user_data subdirectories exist
  testthat::expect_true(dir.exists(file.path(result$user_data_dir, "training_answers_not_saved")))
  testthat::expect_true(dir.exists(file.path(result$user_data_dir, "institute1")))
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_config function
testthat::test_that("init_external_config creates configuration correctly", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_config_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Test config creation
  config_file <- init_external_config(test_base)

  expected_config_file <- file.path(test_base, "config", "config.yaml")
  testthat::expect_equal(config_file, expected_config_file)
  testthat::expect_true(file.exists(config_file))
  
  # Check that config directory was created
  config_dir <- file.path(test_base, "config")
  testthat::expect_true(dir.exists(config_dir))
  
  # Check that config file has content
  config_content <- yaml::read_yaml(config_file)
  testthat::expect_true(is.list(config_content))
  testthat::expect_true("application_title" %in% names(config_content))
  
  # Check that environment variable was set
  testthat::expect_equal(Sys.getenv("IMGVOTER_CONFIG_PATH"), config_file)
  
  # Test that existing config is detected
  config_file2 <- init_external_config(test_base)
  testthat::expect_equal(config_file, config_file2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
  Sys.unsetenv("IMGVOTER_CONFIG_PATH")
})

# Test file.symlink.exists function (internal function)
testthat::test_that("file.symlink.exists works correctly", {
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
testthat::test_that("init_external_images creates images directory", {
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
  testthat::expect_equal(images_dir, expected_images_dir)
  testthat::expect_true(dir.exists(images_dir))
  testthat::expect_true(file.symlink.exists(file.path(app_dir, "www", "images")))
  # Check that symlink points to the correct directory
  testthat::expect_equal(
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
testthat::test_that("init_external_server_data creates server data directory", {
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_server_data_init")
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  
  # Test server_data directory creation
  server_data_dir <- init_external_server_data(test_base)
  
  expected_server_data_dir <- file.path(test_base, "server_data")
  testthat::expect_equal(server_data_dir, expected_server_data_dir)
  testthat::expect_true(dir.exists(server_data_dir))
  
  # Check that README was created
  readme_file <- file.path(server_data_dir, "README.md")
  testthat::expect_true(file.exists(readme_file))
  
  readme_content <- readLines(readme_file)
  testthat::expect_true(any(grepl("Server Data Directory", readme_content)))
  
  # Test that existing directory is handled correctly
  server_data_dir2 <- init_external_server_data(test_base)
  testthat::expect_equal(server_data_dir, server_data_dir2)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_environment function
testthat::test_that("init_external_environment sets up complete environment with variables", {
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
  testthat::expect_true(is.list(result))
  expected_keys <- c("user_data_dir", "db_file", "config_file", "images_dir", "server_data_dir")
  testthat::expect_true(all(expected_keys %in% names(result)))
  
  # Check that all directories and files were created
  testthat::expect_true(dir.exists(result$user_data_dir))
  testthat::expect_true(file.exists(result$db_file))
  testthat::expect_true(file.exists(result$config_file))
  testthat::expect_true(dir.exists(result$images_dir))
  testthat::expect_true(dir.exists(result$server_data_dir))
  
  # Check that environment variables were set correctly
  testthat::expect_equal(Sys.getenv("IMGVOTER_USER_DATA_DIR"), result$user_data_dir)
  testthat::expect_equal(Sys.getenv("IMGVOTER_DATABASE_PATH"), result$db_file)
  testthat::expect_equal(Sys.getenv("IMGVOTER_CONFIG_PATH"), result$config_file)
  testthat::expect_equal(Sys.getenv("IMGVOTER_IMAGES_DIR"), result$images_dir)
  testthat::expect_equal(Sys.getenv("IMGVOTER_SERVER_DATA_DIR"), result$server_data_dir)
  
  # Check that user_data subdirectories exist
  testthat::expect_true(dir.exists(file.path(result$user_data_dir, "institute1")))
  testthat::expect_true(dir.exists(file.path(result$user_data_dir, "training_answers_not_saved")))
  
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

testthat::test_that("generate_password creates valid passwords", {
  # Test default length
  password1 <- generate_password()
  expect_type(password1, "character")
  testthat::expect_equal(nchar(password1), 12)
  
  # Test custom length
  password2 <- generate_password(8)
  testthat::expect_equal(nchar(password2), 8)
  
  # Test that passwords are different
  password3 <- generate_password()
  expect_false(password1 == password3)

  # Define allowed characters
  chars <- c(letters, LETTERS, as.character(0:9), strsplit("!@#$%^&*", "")[[1]])
  
  # Check all characters in password are valid
  password_chars <- strsplit(password1, "")[[1]]
  testthat::expect_true(all(password_chars %in% chars))
})

# Test init_external_database with user population
testthat::test_that("init_external_database populates users from institute2userids2password.yaml", {
  app_dir <- ShinyImgVoteR::get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_db_user_population")
  config_dir <- file.path(app_dir, "config")

  Sys.setenv("IMGVOTER_CONFIG_DIR" = config_dir)
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  dir.create(test_base, recursive = TRUE)
  
  # Test database creation with user population
  # browser()
  
  # debugonce(ShinyImgVoteR::init_external_database)
  db_path <- ShinyImgVoteR::init_external_database(test_base, "test_users_db.sqlite")
  
  expected_db_path <- file.path(test_base, "test_users_db.sqlite")
  testthat::expect_equal(db_path, expected_db_path)
  testthat::expect_true(file.exists(db_path))
  
  # Check database structure includes passwords table
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  tables <- DBI::dbListTables(con)
  testthat::expect_true("passwords" %in% tables)
  
  # Check passwords table structure
  passwords_info <- DBI::dbGetQuery(con, "PRAGMA table_info(passwords)")
  expected_passwords_columns <- c("userid", "institute", "password", 
                                  "password_retrieval_link", "link_clicked_timestamp")
  testthat::expect_true(all(expected_passwords_columns %in% passwords_info$name))
  
  # Check that users were populated
  users <- DBI::dbGetQuery(con, "SELECT userid, institute, password FROM passwords ORDER BY userid")
  testthat::expect_equal(nrow(users), 4)
  testthat::expect_true(all(c("test", "test2", "user", "user2") %in% users$userid))
  testthat::expect_true(all(c("training_answers_not_saved", "institute1") %in% users$institute))

  # filter the users_df by institute
  institute1_users <- users[users$institute == "institute1", ]
  testthat::expect_equal(nrow(institute1_users), 2)
  testthat::expect_true(all(c("user", "user2") %in% institute1_users$userid))

  # check that passwords were generated
  passwords <- users[!users$userid %in% c("test", "test2"), ]
  testthat::expect_equal(nrow(passwords), 2)  # Should be 2 generated passwords
  testthat::expect_true(all(nchar(passwords$password) == 12))  # Default password length
  testthat::expect_true(length(unique(passwords$password)) == 2)  # All passwords should be unique

  DBI::dbDisconnect(con)
  
  # Test that running again doesn't duplicate users and does not change existing passwords
  db_path2 <- ShinyImgVoteR::init_external_database(test_base, "test_users_db.sqlite")
  testthat::expect_equal(db_path, db_path2)

  con2 <- DBI::dbConnect(RSQLite::SQLite(), db_path2)
  users2 <- DBI::dbGetQuery(con2, "SELECT userid, institute, password FROM passwords ORDER BY userid")
  testthat::expect_equal(nrow(users2), 4)  # Should still be 4 users, not 8

  # passwords should not change
  testthat::expect_equal(users2$userid, users$userid)
  testthat::expect_equal(users2$institute, users$institute)
  testthat::expect_equal(users2$password, users$password)

  DBI::dbDisconnect(con2)

  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_external_database with preset passwords
testthat::test_that("init_external_database handles preset passwords correctly", {
  app_dir <- ShinyImgVoteR::get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_db_preset_passwords")
  config_dir <- file.path(app_dir, "config")

  Sys.setenv("IMGVOTER_CONFIG_DIR" = config_dir)
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  dir.create(test_base, recursive = TRUE)
  
  # Test database creation with user population
  db_path <- init_external_database(test_base, "test_preset_db.sqlite")
  
  expected_db_path <- file.path(test_base, "test_preset_db.sqlite")
  testthat::expect_equal(db_path, expected_db_path)
  testthat::expect_true(file.exists(db_path))
  
  # Check database structure includes passwords table
  con <- dbConnect(RSQLite::SQLite(), db_path)
  tables <- dbListTables(con)
  testthat::expect_true("passwords" %in% tables)
  
  # Check that users were populated with correct passwords
  users <- dbGetQuery(con, "SELECT userid, institute, password FROM passwords ORDER BY userid")
  testthat::expect_equal(nrow(users), 4)
  
  # Check preset passwords
  test_user <- users[users$userid == "test", ]
  testthat::expect_equal(test_user$password, "1234")
  
  test2_user <- users[users$userid == "test2", ]
  testthat::expect_equal(test2_user$password, "abcd")
  
  # Check generated passwords (should be 12 characters)
  test3_user <- users[users$userid == "user", ]
  testthat::expect_equal(nchar(test3_user$password), 12)

  test4_user <- users[users$userid == "user2", ]
  testthat::expect_equal(nchar(test4_user$password), 12)

  # Ensure generated passwords are different from preset ones
  testthat::expect_true(test3_user$password != "1234")
  testthat::expect_true(test4_user$password != "abcd")
  
  testthat::expect_true(test3_user$password != test4_user$password)
  
  dbDisconnect(con)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})

# Test init_user_data_structure with YAML institutes
testthat::test_that("init_user_data_structure reads institutes from YAML file", {
  app_dir <- ShinyImgVoteR::get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_user_data_yaml")
  config_dir <- file.path(app_dir, "config")

  Sys.setenv("IMGVOTER_CONFIG_DIR" = config_dir)
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  dir.create(test_base, recursive = TRUE)
  
  # Test user data structure creation
  user_data_dir <- ShinyImgVoteR::init_user_data_structure(test_base)
  
  expected_user_data_dir <- file.path(test_base, "user_data")
  testthat::expect_equal(user_data_dir, expected_user_data_dir)
  testthat::expect_true(dir.exists(user_data_dir))
  
  # Check that directories were created for institutes from YAML
  testthat::expect_true(dir.exists(file.path(user_data_dir, "training_answers_not_saved")))
  testthat::expect_true(dir.exists(file.path(user_data_dir, "institute1")))
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})
