library(testthat)
library(DBI)
library(RSQLite)
library(digest)
library(yaml)

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
testthat::test_that("populates users from institute2userids2password.yaml", {
  app_dir <- ShinyImgVoteR::get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_db_user_population")
  config_dir <- file.path(app_dir,"default_env","config")
  images_dir <- file.path(app_dir, "default_env", "images")

  Sys.setenv(
    IMGVOTER_BASE_DIR = test_base,
    IMGVOTER_IMAGES_DIR = images_dir,
    IMGVOTER_TO_BE_VOTED_IMAGES_FILE = file.path(images_dir, "to_be_voted_images.tsv")
  )
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  dir.create(test_base, recursive = TRUE)
  
  # browser()
  cfg <- ShinyImgVoteR::load_config()
  ShinyImgVoteR::init_environment(
    config_file_path = file.path(config_dir,"config.yaml")
  )

  con <- DBI::dbConnect(RSQLite::SQLite(), cfg$sqlite_file)
  
  # Check database structure includes passwords table
  # con <- DBI::dbConnect(RSQLite::SQLite(), cfg$sqlite_file)
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
  ShinyImgVoteR::init_environment(
    config_file_path = file.path(config_dir,"config.yaml")
  )

  con2 <- DBI::dbConnect(RSQLite::SQLite(), cfg$sqlite_file)
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
testthat::test_that("database handles preset passwords correctly", {
  app_dir <- ShinyImgVoteR::get_app_dir()
  temp_dir <- tempdir()
  test_base <- file.path(temp_dir, "test_db_preset_passwords")
  config_dir <- file.path(app_dir,"default_env","config")
  images_dir <- file.path(app_dir, "default_env", "images")

  Sys.setenv(
    IMGVOTER_BASE_DIR = test_base,
    IMGVOTER_IMAGES_DIR = images_dir,
    IMGVOTER_TO_BE_VOTED_IMAGES_FILE = file.path(images_dir, "to_be_voted_images.tsv")
  )
  
  # Clean up any existing directory
  if (dir.exists(test_base)) {
    unlink(test_base, recursive = TRUE)
  }
  dir.create(test_base, recursive = TRUE)

  cfg <- ShinyImgVoteR::load_config()
  ShinyImgVoteR::init_environment(
    config_file_path = file.path(config_dir,"config.yaml")
  )

  con <- DBI::dbConnect(RSQLite::SQLite(), cfg$sqlite_file)
   
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
  
  DBI::dbDisconnect(con)
  
  # Clean up
  unlink(test_base, recursive = TRUE)
})