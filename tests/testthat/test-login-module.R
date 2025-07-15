library(testthat)
library(shiny)
library(DBI)
library(RSQLite)
library(pool)
library(tibble)
library(lubridate)
library(ShinyImgVoteR)

# locate the directory where inst/shiny-app was installed
# app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

# source necessary files
# source(file.path(app_dir, "config.R"))
# source(file.path(app_dir, "modules", "login_module.R"))

test_that("Login UI renders correctly", {
  ui <- loginUI("test")
  expect_s3_class(ui, "shiny.tag")
  
  # Check that the UI contains expected elements
  ui_html <- as.character(ui)
  expect_true(grepl("Welcome to", ui_html))
  # expect_true(grepl("Institute", ui_html))
})

test_that("Database session management functions work", {
  
  # Create test database
  test_db <- create_mock_db()
  conn <- test_db$pool
  
  # Test session ID insertion
  testServer(loginServer, args = list(db_conn = conn), {
    # Test add_sessionid_to_db function
    session$setInputs(institutes_id = "CNAG")
    
    # Simulate adding a session ID
    user <- "test_user"
    sessionid <- "test_session_123"
    
    # The function should be accessible within the module
#expect_true(exists("add_sessionid_to_db", envir = session))
    
    # Add session to database
    add_sessionid_to_db(user, sessionid, conn)
    
    # Verify the session was added
    sessions <- dbReadTable(conn, "sessionids")
    print("Sessions in DB:")
    print(sessions)
    expect_equal(nrow(sessions), 1)
    expect_equal(sessions$user[1], user)
    expect_equal(sessions$sessionid[1], sessionid)
    expect_false(is.na(sessions$login_time[1]))
    expect_true(is.na(sessions$logout_time[1]))
  })
  poolClose(conn)
  unlink(test_db$file)
})

test_that("Logout time update works correctly", {
  
  # Create test database
  test_db <- create_mock_db()
  conn <- test_db$pool
  
  # Insert a test session
  sessionid <- "test_session_456"
  DBI::dbExecute(conn, "
    INSERT INTO sessionids (user, sessionid, login_time, logout_time)
    VALUES (?, ?, ?, ?)
  ", params = list("test_user", sessionid, as.character(now()), NA_character_))
  
  testServer(loginServer, args = list(db_conn = conn), {
    # Update logout time
    update_logout_time_in_db(sessionid, conn)
    
    # Verify logout time was updated
    sessions <- dbReadTable(conn, "sessionids")
    expect_false(is.na(sessions$logout_time[1]))
  })
  
  # Clean up
  poolClose(conn)
  unlink(test_db$file)
})

test_that("Session filtering works correctly", {
  
  # Create test database
  test_db <- create_mock_db()
  conn <- test_db$pool
  
  # Insert test sessions with different states
  current_time <- now()
  old_time <- current_time - days(2)
  
  # Active session (recent, no logout)
  DBI::dbExecute(conn, "
    INSERT INTO sessionids (user, sessionid, login_time, logout_time)
    VALUES (?, ?, ?, ?)
  ", params = list("user1", "session1", as.character(current_time), NA_character_))
  
  # Expired session (old, no logout)
  DBI::dbExecute(conn, "
    INSERT INTO sessionids (user, sessionid, login_time, logout_time)
    VALUES (?, ?, ?, ?)
  ", params = list("user2", "session2", as.character(old_time), NA_character_))
  
  # Logged out session (recent, has logout)
  DBI::dbExecute(conn, "
    INSERT INTO sessionids (user, sessionid, login_time, logout_time)
    VALUES (?, ?, ?, ?)
  ", params = list("user3", "session3", as.character(current_time), as.character(current_time)))
  
  testServer(loginServer, args = list(db_conn = conn), {
    # Get active sessions (should only return session1)
    active_sessions <- get_sessionids_from_db(conn, expiry = 1)
    expect_equal(nrow(active_sessions), 1)
    expect_equal(active_sessions$sessionid[1], "session1")
  })
  
  # Clean up
  poolClose(conn)
  unlink(test_db$file)
})

test_that("Login data reactive works correctly", {
  # Create test database
  test_db <- create_mock_db()
  conn <- test_db$pool
  
  testServer(loginServer, args = list(db_conn = conn), {
    # Set institute input
    session$setInputs(institutes_id = "CNAG")
    
    # Mock credentials return value
    # Note: In a real test, you would need to properly mock the shinyauthr response
    # This is a simplified test structure
    expect_true(is.reactive(login_data))
  })
  
  # Clean up
  poolClose(conn)
  unlink(test_db$file)
})
