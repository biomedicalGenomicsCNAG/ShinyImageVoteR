#' Database Utility Functions
#'
#' Utility functions for database operations in the B1MG Variant Voting application.
#'
#' @name db_utils
NULL

#' Create a test database pool
#'
#' Creates a temporary SQLite database pool for testing purposes.
#'
#' @return List containing pool object and database file path
#' @export
create_test_db_pool <- function() {
  db_file <- tempfile(fileext = ".sqlite")
  pool <- pool::dbPool(RSQLite::SQLite(), dbname = db_file)
  
  # Create required tables
  DBI::dbExecute(pool, "
    CREATE TABLE annotations (
      coordinates TEXT,
      REF TEXT,
      ALT TEXT,
      variant TEXT,
      path TEXT,
      vote_count_correct INTEGER DEFAULT 0,
      vote_count_no_variant INTEGER DEFAULT 0,
      vote_count_different_variant INTEGER DEFAULT 0,
      vote_count_not_sure INTEGER DEFAULT 0,
      vote_count_total INTEGER DEFAULT 0
    )
  ")
  
  DBI::dbExecute(pool, "
    CREATE TABLE sessionids (
      user TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")
  
  # Insert some test data
  DBI::dbExecute(pool, "
    INSERT INTO annotations (coordinates, REF, ALT, variant, path)
    VALUES 
      ('chr1:1000', 'A', 'T', 'SNV', '/path/to/image1.png'),
      ('chr2:2000', 'G', 'C', 'SNV', '/path/to/image2.png'),
      ('chr3:3000', 'AT', 'A', 'DEL', '/path/to/image3.png')
  ")
  
  return(list(pool = pool, file = db_file))
}

#' Generate randomization seed
#'
#' Generates a consistent randomization seed based on user ID and timestamp.
#'
#' @param user_id Character. The user ID
#' @param timestamp Numeric. Optional timestamp (uses current time if not provided)
#' @return Integer. The generated seed
#' @export
generate_user_seed <- function(user_id, timestamp = NULL) {
  if (is.null(timestamp)) {
    timestamp <- as.numeric(Sys.time())
  }
  
  combined <- paste0(user_id, timestamp)
  seed <- strtoi(substr(digest::digest(combined, algo = "crc32"), 1, 7), base = 16)
  return(seed)
}

#' Initialize user data directory structure
#'
#' Creates the external user_data directory structure with institute subdirectories.
#'
#' @param base_dir Character. Base directory where user_data should be created. 
#'   Defaults to current working directory.
#' @return Character path to the created user_data directory
#' @export
init_user_data_structure <- function(base_dir = getwd()) {
  user_data_dir <- file.path(base_dir, "user_data")
  
  # Create main user_data directory
  if (!dir.exists(user_data_dir)) {
    dir.create(user_data_dir, recursive = TRUE)
    cat("Created user_data directory at:", user_data_dir, "\n")
  }
  
  # Create institute subdirectories
  institutes <- c(
    "CNAG", "DKFZ", "DNGC", "FPGMX", "Hartwig", "ISCIII", 
    "KU_Leuven", "Latvian_BRSC", "MOMA", "SciLifeLab",
    "Training_answers_not_saved", "Universidade_de_Aveiro",
    "University_of_Helsinki", "University_of_Oslo", 
    "University_of_Verona"
  )
  
  for (institute in institutes) {
    institute_dir <- file.path(user_data_dir, institute)
    if (!dir.exists(institute_dir)) {
      dir.create(institute_dir, recursive = TRUE)
      cat("Created institute directory:", institute_dir, "\n")
    }
  }
  
  return(user_data_dir)
}

#' Initialize external database
#'
#' Sets up the SQLite database file outside the package.
#'
#' @param base_dir Character. Base directory for database (default: current working directory)
#' @param db_name Character. Name of the database file (default: "db.sqlite")
#' @return Character path to the database file
#' @export
init_external_database <- function(base_dir = getwd(), db_name = "db.sqlite") {
  db_path <- file.path(base_dir, db_name)
  
  # Check if database already exists
  if (file.exists(db_path)) {
    cat("Database already exists:", db_path, "\n")
    return(db_path)
  }
  
  # Check if there's a database in the package to copy
  app_dir <- get_app_dir()
  package_db <- file.path(app_dir, db_name)
  
  if (file.exists(package_db)) {
    # Copy database from package
    file.copy(package_db, db_path)
    cat("Copied database from package to:", db_path, "\n")
  } else {
    # Create new empty database
    cat("Creating new database:", db_path, "\n")
    
    # Create a minimal database structure
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    
    # Create basic tables (you may need to adjust this based on your schema)
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS annotations (
        coordinates TEXT,
        REF TEXT,
        ALT TEXT,
        variant TEXT,
        path TEXT,
        vote_count_correct INTEGER DEFAULT 0,
        vote_count_no_variant INTEGER DEFAULT 0,
        vote_count_different_variant INTEGER DEFAULT 0,
        vote_count_not_sure INTEGER DEFAULT 0,
        vote_count_total INTEGER DEFAULT 0
      )
    ")
    
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS sessionids (
        user TEXT,
        sessionid TEXT,
        login_time TEXT,
        logout_time TEXT
      )
    ")
    
    DBI::dbDisconnect(con)
  }
  
  return(db_path)
}

#' Setup complete external environment
#'
#' Sets up both user_data directory and database outside the package.
#'
#' @param base_dir Character. Base directory for setup (default: current working directory)
#' @return List with paths to user_data directory and database file
#' @export
setup_external_environment <- function(base_dir = getwd()) {
  user_data_dir <- init_user_data_structure(base_dir)
  db_path <- init_external_database(base_dir)
  
  cat("\n=== EXTERNAL ENVIRONMENT SETUP COMPLETE ===\n")
  cat("User data directory:", user_data_dir, "\n")
  cat("Database file:", db_path, "\n")
  cat("Base directory:", base_dir, "\n")
  
  return(list(
    user_data_dir = user_data_dir,
    database_path = db_path,
    base_dir = base_dir
  ))
}

#' Initialize external environment for the application
#'
#' Sets up the external directory structure and database for the application.
#'
#' @param base_dir Character. Base directory for external files. 
#'   Defaults to current working directory.
#' @return List with paths to user_data directory and database file
#' @export
init_external_environment <- function(base_dir = getwd()) {
  # Initialize user data structure
  user_data_dir <- init_user_data_structure(base_dir)
  
  # Set up database path
  db_file <- file.path(base_dir, "db.sqlite")
  
  # Create database if it doesn't exist
  if (!file.exists(db_file)) {
    cat("Database file will be created at:", db_file, "\n")
  } else {
    cat("Using existing database at:", db_file, "\n")
  }
  
  return(list(
    user_data_dir = user_data_dir,
    db_file = db_file
  ))
}
