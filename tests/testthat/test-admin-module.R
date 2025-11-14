library(testthat)
library(shiny)
library(ShinyImgVoteR)

testthat::test_that("Admin module UI renders correctly", {
  cfg <- ShinyImgVoteR::load_config()
  ui_result <- ShinyImgVoteR::adminUI("test", cfg)
  expect_s3_class(ui_result, "shiny.tag.list")
  
  ui_html <- as.character(ui_result)
  testthat::expect_true(grepl("users_table", ui_html))
  testthat::expect_true(grepl("refresh_tokens", ui_html))
  testthat::expect_true(grepl("download_annotations_btn", ui_html))
})

testthat::test_that("Admin module counts votes correctly", {
  cfg <- ShinyImgVoteR::load_config()
  
  # Create test directory structure
  temp_dir <- tempdir()
  test_user_data_dir <- file.path(temp_dir, "admin_test_user_data")
  dir.create(test_user_data_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Create test institute and user directories
  institute_dir <- file.path(test_user_data_dir, "TestInstitute")
  user_dir <- file.path(institute_dir, "test_user")
  dir.create(user_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Create test annotations file with votes
  annotations_file <- file.path(user_dir, "test_user_annotations.tsv")
  write.table(
    data.frame(
      coordinates = c("chr1:1000", "chr2:2000", "chr3:3000"),
      agreement = c("yes", "no", "yes"),
      alternative_vartype = c("", "", ""),
      observation = c("", "", ""),
      comment = c("", "", ""),
      shinyauthr_session_id = c("session1", "session2", "session3"),
      time_till_vote_casted_in_seconds = c("5", "3", "7")
    ),
    file = annotations_file,
    sep = "\t",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  
  # Create mock database
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  
  # Insert test user
  DBI::dbExecute(
    db_pool,
    "INSERT INTO passwords (userid, institute, password, pwd_retrieval_token, pwd_retrieved_timestamp) 
     VALUES (?, ?, ?, ?, ?)",
    params = list("test_user", "TestInstitute", "password123", "token123", NA)
  )
  
  # Override cfg user_data_dir for testing
  cfg$user_data_dir <- test_user_data_dir
  
  login_trigger <- shiny::reactiveVal(list(user_id = "admin_user", admin = 1))
  
  shiny::testServer(ShinyImgVoteR::adminServer, args = list(
    id = "test",
    cfg = cfg,
    login_trigger = login_trigger,
    db_pool = db_pool
  ), {
    # Test that the users table includes vote counts
    users <- users_tbl()
    testthat::expect_true(is.data.frame(users))
    testthat::expect_true("votes_count" %in% names(users))
    
    # Test that vote count is calculated correctly (3 votes with session IDs)
    test_user_row <- users[users$userid == "test_user", ]
    testthat::expect_equal(nrow(test_user_row), 1)
    testthat::expect_equal(test_user_row$votes_count, 3)
  })
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(test_user_data_dir, recursive = TRUE)
  unlink(mock_db$file)
})

testthat::test_that("Admin module handles users with no votes", {
  cfg <- ShinyImgVoteR::load_config()
  
  # Create test directory structure
  temp_dir <- tempdir()
  test_user_data_dir <- file.path(temp_dir, "admin_test_no_votes")
  dir.create(test_user_data_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Create mock database
  mock_db <- create_mock_db()
  db_pool <- mock_db$pool
  
  # Insert test user without any annotation file
  DBI::dbExecute(
    db_pool,
    "INSERT INTO passwords (userid, institute, password, pwd_retrieval_token, pwd_retrieved_timestamp) 
     VALUES (?, ?, ?, ?, ?)",
    params = list("user_no_votes", "TestInstitute", "password123", "token456", NA)
  )
  
  # Override cfg user_data_dir for testing
  cfg$user_data_dir <- test_user_data_dir
  
  login_trigger <- shiny::reactiveVal(list(user_id = "admin_user", admin = 1))
  
  shiny::testServer(ShinyImgVoteR::adminServer, args = list(
    id = "test",
    cfg = cfg,
    login_trigger = login_trigger,
    db_pool = db_pool
  ), {
    # Test that users table includes vote counts even for users without annotations
    users <- users_tbl()
    testthat::expect_true(is.data.frame(users))
    
    test_user_row <- users[users$userid == "user_no_votes", ]
    testthat::expect_equal(nrow(test_user_row), 1)
    testthat::expect_equal(test_user_row$votes_count, 0)
  })
  
  # Clean up
  pool::poolClose(db_pool)
  unlink(test_user_data_dir, recursive = TRUE)
  unlink(mock_db$file)
})
