#' Get or create the user data directory
#'
#' This function returns the path to the user_data directory, creating it if necessary.
#' The directory is located outside the package installation.
#'
#' @param base_dir Character. Base directory where user_data should be located. 
#'   If NULL, uses the current working directory.
#' @return Character path to the user_data directory
#' @export
get_user_data_dir <- function(base_dir = NULL) {
  if (is.null(base_dir) || base_dir == "") {
    base_dir <- getwd()
  }
  
  user_data_dir <- file.path(base_dir, "user_data")
  
  # Create the directory if it doesn't exist
  if (!dir.exists(user_data_dir)) {
    dir.create(user_data_dir, recursive = TRUE, showWarnings = FALSE)
    message("Created user_data directory at: ", user_data_dir)
  }
  return(user_data_dir)
}

#' Initialize the database connection pool
#' @keywords internal
#' @param cfg_sqlite_file Path to an existing SQLite file
#' @return A DBI pool object
#' @export
init_db <- function(cfg_sqlite_file) {
  pool <- pool::dbPool(
    RSQLite::SQLite(),
    dbname = cfg_sqlite_file
  )

  shiny::onStop(function() {
    pool::poolClose(pool)
  })

  return(pool)
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

  browser()
  
  # Check if database already exists
  if (file.exists(db_path)) {
    cat("Database already exists:", db_path, "\n")
    return(db_path)
  }
  
  cat("Creating new database:", db_path, "\n")
  
  # Look for data file in config/annotation_screenshots_paths first
  config_data_file <- file.path(base_dir, "config", "annotation_screenshots_paths", "uro003_paths_mock.txt")
  
  # If not found externally, try the package location as fallback
  app_dir <- get_app_dir()
  package_data_file <- file.path(app_dir, "screenshots", "uro003_paths_mock.txt")
  
  data_file <- NULL
  if (file.exists(config_data_file)) {
    data_file <- config_data_file
    cat("Using external data file:", data_file, "\n")
  } else if (file.exists(package_data_file)) {
    data_file <- package_data_file
    cat("Using package data file:", data_file, "\n")
  }
  
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

    DBI::dbExecute(con, "
      CREATE TABLE passwords (
        userid TEXT PRIMARY KEY,
        institute TEXT,
        password TEXT,
        password_retrieval_link TEXT,
        link_clicked_timestamp TEXT
      )
    ")
    
    # Populate users from institute2userids2password.yaml if available
    institute_file <- file.path(
      Sys.getenv("IMGVOTER_CONFIG_DIR"),
      "institute2userids2password.yaml"
    )
    if (file.exists(institute_file)) {
      cat("Found institute2userids2password.yaml, populating users...\n")
      
      # Read the institute2userids2password.yaml file
      institute_data <- yaml::read_yaml(institute_file)
      
      # Extract all userids with their institutes and preset passwords
      user_institute_map <- data.frame(
        userid = character(0), 
        institute = character(0), 
        preset_password = character(0),
        stringsAsFactors = FALSE
      )
      
      for (institute in names(institute_data)) {
        users <- institute_data[[institute]]
        
        # Process each user entry
        for (user_entry in users) {
          if (is.list(user_entry) && length(user_entry) == 1) {
            # Format: - username: password
            username <- names(user_entry)[1]
            preset_password <- as.character(user_entry[[1]])
          } else if (is.character(user_entry)) {
            # Format: - username (no preset password)
            username <- trimws(gsub("^-", "", user_entry))
            preset_password <- NA_character_
          } else {
            # Convert to character and treat as simple username
            username <- trimws(gsub("^-", "", as.character(user_entry)))
            preset_password <- NA_character_
          }
          
          # Add to the mapping
          institute_user <- data.frame(
            userid = username,
            institute = institute,
            preset_password = preset_password,
            stringsAsFactors = FALSE
          )
          user_institute_map <- rbind(user_institute_map, institute_user)
        }
      }
      
      userids <- user_institute_map$userid
      cat("Found users from config:", paste(userids, collapse = ", "), "\n")
      
      # Prepare data for insertion (no existing users in new database)
      user_data <- data.frame(
        userid = user_institute_map$userid,
        institute = user_institute_map$institute,
        password = ifelse(
          is.na(user_institute_map$preset_password),
          sapply(user_institute_map$userid, function(x) generate_password()),
          user_institute_map$preset_password
        ),
        password_retrieval_link = NA_character_,
        link_clicked_timestamp = NA_character_,
        stringsAsFactors = FALSE
      )

      # filter the user_data frame for user
      
      # Insert users
      DBI::dbWriteTable(con, "passwords", user_data, append = TRUE)
      cat("Added", nrow(user_data), "users to the database\n")
      
      # Display the added users and their passwords
      cat("\nAdded users and their passwords:\n")
      for (i in 1:nrow(user_data)) {
        cat("User:", user_data$userid[i], "Institute:", user_data$institute[i], "Password:", user_data$password[i], "\n")
      }
    } else {
      cat("institute2userids2password.yaml not found at:", institute_file, "\n")
      cat("Skipping user population. Users can be added manually to the database.\n")
    }
    
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
  
  # TODO define column names (from config.yaml)
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

  if (!"passwords" %in% DBI::dbListTables(con)) {
    cat("Creating passwords table\n")
    DBI::dbExecute(con, "
      CREATE TABLE passwords (
        userid TEXT PRIMARY KEY,
        institute TEXT,
        password TEXT,
        password_retrieval_link TEXT,
        link_clicked_timestamp TEXT
      )
    ")
  }
  
  # Populate users from institute2userids2password.yaml if available
  institute_file <- file.path(
    Sys.getenv("IMGVOTER_CONFIG_DIR"),
    "institute2userids2password.yaml"
  )

  if (!file.exists(institute_file)) {
    cat("institute2userids2password.yaml not found at:", institute_file, "\n")
    stop()
  }

  if (file.exists(institute_file)) {
    cat("Found institute2userids2password.yaml, populating users...\n")
    
    # Read the institute2userids2password.yaml file
    institute_data <- yaml::read_yaml(institute_file)
    
    # Extract all userids with their institutes and preset passwords
    user_institute_map <- data.frame(
      userid = character(0), 
      institute = character(0), 
      preset_password = character(0),
      stringsAsFactors = FALSE
    )

    print("user_institute_map:")
    print(user_institute_map)
    
    for (institute in names(institute_data)) {
      users <- institute_data[[institute]]
      
      # Process each user entry
      for (user_entry in users) {
        if (is.list(user_entry) && length(user_entry) == 1) {
          # Format: - username: password
          username <- names(user_entry)[1]
          preset_password <- as.character(user_entry[[1]])
        } else if (is.character(user_entry)) {
          # Format: - username (no preset password)
          username <- trimws(gsub("^-", "", user_entry))
          preset_password <- NA_character_
        } else {
          # Convert to character and treat as simple username
          username <- trimws(gsub("^-", "", as.character(user_entry)))
          preset_password <- NA_character_
        }
        
        # Add to the mapping
        institute_user <- data.frame(
          userid = username,
          institute = institute,
          preset_password = preset_password,
          stringsAsFactors = FALSE
        )
        user_institute_map <- rbind(user_institute_map, institute_user)
      }
    }
    
    userids <- user_institute_map$userid
    cat("Found users from config:", paste(userids, collapse = ", "), "\n")
    
    # Check current users in the database
    existing_users <- DBI::dbGetQuery(con, "SELECT userid FROM passwords")$userid
    cat("Existing users in database:", paste(existing_users, collapse = ", "), "\n")
    
    # Add new users (skip existing ones)
    new_users <- setdiff(userids, existing_users)
    cat("New users to add:", paste(new_users, collapse = ", "), "\n")
    
    if (length(new_users) > 0) {
      # Get the institute information for new users
      new_user_data <- user_institute_map[user_institute_map$userid %in% new_users, ]
      
      # Prepare data for insertion
      user_data <- data.frame(
        userid = new_user_data$userid,
        institute = new_user_data$institute,
        password = ifelse(
          is.na(new_user_data$preset_password),
          sapply(new_user_data$userid, function(x) generate_password()),
          new_user_data$preset_password
        ),
        password_retrieval_link = NA_character_,
        link_clicked_timestamp = NA_character_,
        stringsAsFactors = FALSE
      )
      
      # Insert new users
      DBI::dbWriteTable(con, "passwords", user_data, append = TRUE)
      cat("Added", length(new_users), "new users to the database\n")
      
      # Display the newly added users and their passwords
      cat("\nNewly added users and their passwords:\n")
      for (i in 1:nrow(user_data)) {
        cat("User:", user_data$userid[i], "Institute:", user_data$institute[i], "Password:", user_data$password[i], "\n")
      }
    } else {
      cat("No new users to add. All users already exist in the database.\n")
    }
  } else {
    cat("institute2userids2password.yaml not found at:", institute_file, "\n")
    cat("Skipping user population. Users can be added manually to the database.\n")
  }
  
  # Show created tables
  tables <- DBI::dbListTables(con)
  cat("Created tables:", paste(tables, collapse = ", "), "\n")
  
  # Get row count for annotations
  row_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM annotations")
  cat("Loaded", row_count$count, "annotations into database\n")
  
  # Show user count if passwords table exists
  if ("passwords" %in% tables) {
    user_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM passwords")
    cat("Total users in database:", user_count$count, "\n")
  }
  
  DBI::dbDisconnect(con)
  
  return(db_path)
}


#' Initialize external environment for the application
#'
#' Sets up the external directory structure, database, and configuration for the application.
#'
#' @param base_dir Character. Base directory for external files. 
#'   Defaults to current working directory.
#' @return List with paths to user_data directory, database file, and config file
#' @export
copy_dir_from_app <- function(target_dir_path) {
  app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

  target_dir_name <- basename(target_dir_path)
  dir_to_copy <- file.path(app_dir,"default_env",target_dir_name)

  R.utils::copyDirectory(
    from = dir_to_copy,
    to = target_dir_path
  )

  message(glue::glue(
    "Copied {target_dir_name} directory from ShinyImgVoteR",
    " to {target_dir_path}"
  ))
  return(normalizePath(target_dir_path, mustWork = TRUE))
}


#' Initialize environment for the application
#'
#' Sets up the app environment directory and the database.
#'
#' @param config_file_path Character. Path to the configuration file.
#'    Default is app_env/config/config.yaml in the current working directory.
#' @return List with paths to user_data directory, database file, and config file
#' @export  
init_environment <- function(
  config_file_path,
  base_dir = getwd()
) {

  browser()
  default_file_path <- file.path(
    get_app_dir(), "default_env", "config", "config.yaml"
  )

  if (config_file_path == default_file_path) {
    config_dir <- file.path(base_dir, "app_env", "config")
  }

  if(!dir.exists(config_dir)) {
    copy_dir_from_app(config_dir)
  }

  cfg <- load_config2(config_file_path)

  # Set up expected directories
  expected_dirs <- c("images", "user_data", "server_data")
  for (directory in expected_dirs) {
    target_dir_path <- cfg[[glue::glue("{directory}_dir")]]
    full_path <- file.path(base_dir, target_dir_path)
    cat("Checking directory:", target_dir_path, "\n")
    if(!dir.exists(target_dir_path)) {
      full_path <- copy_dir_from_app(target_dir_path)
    }
    if (directory == "images") {
      Sys.setenv(IMGVOTER_IMAGES_DIR = full_path)
    }
  }

  # # Initialize database
  # db_file <- init_external_database(base_dir)
  
  # # Initialize configuration
  # config_file <- init_external_config(base_dir)
  
  # # Initialize images with symlinks
  # images_dir <- init_external_images(base_dir)
  
  # # Initialize server_data directory
  # server_data_dir <- init_external_server_data(base_dir)
  
  # # Set environment variables for the application to use
  # Sys.setenv(IMGVOTER_USER_DATA_DIR = user_data_dir)
  # Sys.setenv(IMGVOTER_DATABASE_PATH = db_file)
  # Sys.setenv(IMGVOTER_CONFIG_PATH = config_file)
  # Sys.setenv(IMGVOTER_IMAGES_DIR = images_dir)
  # Sys.setenv(IMGVOTER_SERVER_DATA_DIR = server_data_dir)
  
  # cat("\nExternal environment initialized successfully!\n")
  # cat("Environment variables set:\n")
  # cat("  IMGVOTER_USER_DATA_DIR =", Sys.getenv("IMGVOTER_USER_DATA_DIR"), "\n")
  # cat("  IMGVOTER_DATABASE_PATH =", Sys.getenv("IMGVOTER_DATABASE_PATH"), "\n")
  # cat("  IMGVOTER_CONFIG_PATH =", Sys.getenv("IMGVOTER_CONFIG_PATH"), "\n")
  # cat("  IMGVOTER_IMAGES_DIR =", Sys.getenv("IMGVOTER_IMAGES_DIR"), "\n")
  # cat("  IMGVOTER_SERVER_DATA_DIR =", Sys.getenv("IMGVOTER_SERVER_DATA_DIR"), "\n")
  
  # return(list(
  #   user_data_dir = user_data_dir,
  #   db_file = db_file,
  #   config_file = config_file,
  #   images_dir = images_dir,
  #   server_data_dir = server_data_dir
  # ))
}
