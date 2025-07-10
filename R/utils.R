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
#' Sets up the SQLite database file outside the package using the same logic as init_db.R.
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
  
  cat("Creating new database:", db_path, "\n")
  
  # Get the app directory to access the data file
  app_dir <- get_app_dir()
  data_file <- file.path(app_dir, "screenshots", "uro003_paths_mock.txt")
  
  # Check if data file exists
  if (!file.exists(data_file)) {
    cat("Warning: Data file not found at", data_file, "\n")
    cat("Creating database with minimal structure...\n")
    
    # Create minimal database structure
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    
    DBI::dbExecute(con, "
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
    
    DBI::dbExecute(con, "
      CREATE TABLE sessionids (
        user TEXT,
        sessionid TEXT,
        login_time TEXT,
        logout_time TEXT
      )
    ")
    
    DBI::dbDisconnect(con)
    return(db_path)
  }
  
  # Load data following init_db.R logic
  df <- read.table(
    data_file, 
    sep = "\t", 
    header = FALSE, 
    stringsAsFactors = FALSE
  )
  
  # Define column names (from config.R)
  cfg_db_general_cols <- c("coordinates", "REF", "ALT", "variant", "path")
  cfg_vote_counts_cols <- c(
    "vote_count_correct",
    "vote_count_no_variant", 
    "vote_count_different_variant",
    "vote_count_not_sure",
    "vote_count_total"
  )
  
  colnames(df) <- cfg_db_general_cols
  df[cfg_vote_counts_cols] <- lapply(cfg_vote_counts_cols, function(x) 0L)
  
  # Point the path to symlinked images directory
  df$path <- gsub("/vol/b1mg/", "images/", df$path)
  
  # Create database connection
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  
  # Write annotations table
  DBI::dbWriteTable(con, "annotations", df, overwrite = TRUE)
  
  # Create trigger for vote total updates
  DBI::dbExecute(con, "
    CREATE TRIGGER update_vote_total_update
    AFTER UPDATE ON annotations
    FOR EACH ROW
    BEGIN
      UPDATE annotations
      SET vote_count_total = 
          vote_count_correct +
          vote_count_no_variant +
          vote_count_different_variant +
          vote_count_not_sure
      WHERE rowid = NEW.rowid;
    END;
  ")
  
  # Create sessionids table if missing
  if (!"sessionids" %in% DBI::dbListTables(con)) {
    cat("Creating sessionids table\n")
    DBI::dbExecute(con, "
      CREATE TABLE sessionids (
        user TEXT,
        sessionid TEXT,
        login_time TEXT,
        logout_time TEXT
      )
    ")
  }
  
  # Show created tables
  tables <- DBI::dbListTables(con)
  cat("Created tables:", paste(tables, collapse = ", "), "\n")
  
  # Get row count for annotations
  row_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM annotations")
  cat("Loaded", row_count$count, "annotations into database\n")
  
  DBI::dbDisconnect(con)
  
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
#' Sets up the external directory structure, database, and configuration for the application.
#'
#' @param base_dir Character. Base directory for external files. 
#'   Defaults to current working directory.
#' @return List with paths to user_data directory, database file, and config file
#' @export
init_external_environment <- function(base_dir = getwd()) {
  cat("Initializing external environment in:", base_dir, "\n")
  
  # Initialize user data structure
  user_data_dir <- init_user_data_structure(base_dir)
  
  # Initialize database
  db_file <- init_external_database(base_dir)
  
  # Initialize configuration
  config_file <- init_external_config(base_dir)
  
  # Set environment variables for the application to use
  Sys.setenv(B1MG_USER_DATA_DIR = user_data_dir)
  Sys.setenv(B1MG_DATABASE_PATH = db_file)
  Sys.setenv(B1MG_CONFIG_PATH = config_file)
  
  cat("\nExternal environment initialized successfully!\n")
  cat("Environment variables set:\n")
  cat("  B1MG_USER_DATA_DIR =", Sys.getenv("B1MG_USER_DATA_DIR"), "\n")
  cat("  B1MG_DATABASE_PATH =", Sys.getenv("B1MG_DATABASE_PATH"), "\n")
  cat("  B1MG_CONFIG_PATH =", Sys.getenv("B1MG_CONFIG_PATH"), "\n")
  
  return(list(
    user_data_dir = user_data_dir,
    db_file = db_file,
    config_file = config_file
  ))
}

#' Initialize external configuration
#'
#' Creates and sources external configuration file for the B1MG Variant Voting application.
#'
#' @param base_dir Character. Base directory for configuration (default: current working directory)
#' @param config_name Character. Name of the configuration file (default: "config.R")
#' @return Character path to the configuration file
#' @export
init_external_config <- function(base_dir = getwd(), config_name = "config.R") {
  config_path <- file.path(base_dir, config_name)
  
  # Check if config already exists
  if (file.exists(config_path)) {
    cat("Configuration file already exists at:", config_path, "\n")
    return(config_path)
  }
  
  # Get the template config from the package
  package_config <- system.file("shiny-app", "config.R", package = "B1MGVariantVoting")
  
  if (package_config == "") {
    stop("Could not find template configuration file in package")
  }
  
  # Copy template to external location
  file.copy(package_config, config_path, overwrite = FALSE)
  
  cat("Configuration file created at:", config_path, "\n")
  cat("You can edit this file to customize the application settings.\n")
  
  return(config_path)
}
