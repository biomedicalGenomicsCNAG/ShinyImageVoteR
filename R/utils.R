#' Generate a random password
#'
#' Creates a random password of specified length using letters, numbers, and special characters.
#'
#' @param length Integer. Length of the password to generate. Defaults to 12.
#' @param pattern Character string. characters to include in the password.
#'
#' @return Character string containing the generated password
generate_password <- function(length = 12, pattern = "!@#$%^&*") {
  chars <- c(letters, LETTERS, as.character(0:9), strsplit(pattern, "")[[1]])
  paste(sample(chars, length, replace = TRUE), collapse = "")
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
  print("Initializing user data structure...")
  print("base_dir:")
  print(base_dir)
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
    institute_file <- file.path(base_dir, "config", "institute2userids2password2password.yaml")
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
  institute_file <- file.path(base_dir, "config", "institute2userids2password.yaml")
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
  
  # Initialize images with symlinks
  images_dir <- init_external_images(base_dir)
  
  # Initialize server_data directory
  server_data_dir <- init_external_server_data(base_dir)
  
  # Set environment variables for the application to use
  Sys.setenv(IMGVOTER_USER_DATA_DIR = user_data_dir)
  Sys.setenv(IMGVOTER_DATABASE_PATH = db_file)
  Sys.setenv(IMGVOTER_CONFIG_PATH = config_file)
  Sys.setenv(IMGVOTER_IMAGES_DIR = images_dir)
  Sys.setenv(IMGVOTER_SERVER_DATA_DIR = server_data_dir)
  
  cat("\nExternal environment initialized successfully!\n")
  cat("Environment variables set:\n")
  cat("  IMGVOTER_USER_DATA_DIR =", Sys.getenv("IMGVOTER_USER_DATA_DIR"), "\n")
  cat("  IMGVOTER_DATABASE_PATH =", Sys.getenv("IMGVOTER_DATABASE_PATH"), "\n")
  cat("  IMGVOTER_CONFIG_PATH =", Sys.getenv("IMGVOTER_CONFIG_PATH"), "\n")
  cat("  IMGVOTER_IMAGES_DIR =", Sys.getenv("IMGVOTER_IMAGES_DIR"), "\n")
  cat("  IMGVOTER_SERVER_DATA_DIR =", Sys.getenv("IMGVOTER_SERVER_DATA_DIR"), "\n")
  
  return(list(
    user_data_dir = user_data_dir,
    db_file = db_file,
    config_file = config_file,
    images_dir = images_dir,
    server_data_dir = server_data_dir
  ))
}

#' Initialize external configuration
#'
#' Initialize external configuration directory and file
#'
#' Creates a config directory and configuration file for the B1MG Variant Voting application.
#'
#' @param base_dir Character. Base directory where config directory should be created (default: current working directory)
#' @return Character path to the configuration file
#' @export
init_external_config <- function(base_dir = getwd()) {
  config_dir <- file.path(base_dir, "config")
  config_file <- file.path(config_dir, "config.yaml")
  
  # Create config directory if it doesn't exist
  if (!dir.exists(config_dir)) {
    dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)
    cat("Created config directory:", config_dir, "\n")
  }
  
  # Check if config already exists
  if (file.exists(config_file)) {
    cat("Configuration file already exists at:", config_file, "\n")
    Sys.setenv(IMGVOTER_CONFIG_PATH = config_file)
    return(config_file)
  }

  package_config <- system.file("shiny-app", "default_config.yaml", package = "ShinyImgVoteR")
  if (package_config == "") {
    stop("Could not find template configuration file in package")
  }

  file.copy(package_config, config_file)
  cat("Configuration file created at:", config_file, "\n")
  
  # Copy annotation_screenshots_paths directory if it doesn't exist
  annotation_dir <- file.path(config_dir, "annotation_screenshots_paths")
  if (!dir.exists(annotation_dir)) {
    # Get the template annotation directory from the package
    package_annotation_dir <- system.file("shiny-app", "config", "annotation_screenshots_paths", package = "ShinyImgVoteR")
    
    if (package_annotation_dir != "" && dir.exists(package_annotation_dir)) {
      # Copy the entire directory
      file.copy(package_annotation_dir, config_dir, recursive = TRUE)
      cat("Copied annotation_screenshots_paths directory to:", annotation_dir, "\n")
    } else {
      # Create the directory and copy just the uro003 file if it exists
      dir.create(annotation_dir, recursive = TRUE, showWarnings = FALSE)
      
      # Try to copy the uro003 file from the package screenshots directory
      package_uro003 <- system.file("shiny-app", "screenshots", "uro003_paths_mock.txt", package = "ShinyImgVoteR")
      if (package_uro003 != "") {
        file.copy(package_uro003, file.path(annotation_dir, "uro003_paths_mock.txt"))
        cat("Copied uro003_paths_mock.txt to:", file.path(annotation_dir, "uro003_paths_mock.txt"), "\n")
      }
    }
  }
  
  cat("You can edit this file to customize the application settings.\n")
  
  # Set environment variable
  Sys.setenv(IMGVOTER_CONFIG_PATH = config_file)
  cat("Set IMGVOTER_CONFIG_PATH to:", config_file, "\n")
  
  return(config_file)
}

#' Setup external images directory with symlinks
#'
#' Creates an external images directory and symlinks it to the Shiny app's www/images folder
#' so images can be served by the Shiny server while being stored outside the package.
#'
#' @param base_dir Character. Base directory for external files (default: current working directory)
#' @param images_subdir Character. Subdirectory name for images (default: "images")
#' @return Character path to the external images directory
#' @export
init_external_images <- function(base_dir = getwd(), images_subdir = "images") {
  # Create external images directory
  external_images_dir <- file.path(base_dir, images_subdir)
  if (!dir.exists(external_images_dir)) {
    dir.create(external_images_dir, recursive = TRUE, showWarnings = FALSE)
    cat("Created external images directory:", external_images_dir, "\n")
  }
  
  # Get the app directory
  app_dir <- get_app_dir()
  if (app_dir == "") {
    warning("Could not find app directory. Symlink setup skipped.")
    return(external_images_dir)
  }
  
  # Define the www/images path in the app
  www_images_path <- file.path(app_dir, "www", "images")
  
  # Remove existing www/images if it's a directory (not a symlink)
  if (dir.exists(www_images_path) && !file.symlink.exists(www_images_path)) {
    cat("Removing existing www/images directory...\n")
    unlink(www_images_path, recursive = TRUE)
  }
  
  # Remove existing symlink if it exists
  if (file.symlink.exists(www_images_path)) {
    cat("Removing existing www/images symlink...\n")
    unlink(www_images_path)
  }
  
  # Create symlink from external images to www/images
  if (file.symlink(external_images_dir, www_images_path)) {
    cat("Created symlink from", external_images_dir, "to", www_images_path, "\n")
  } else {
    warning("Failed to create symlink. Images may not be accessible to Shiny server.")
  }
  
  # Set environment variable for configuration
  Sys.setenv(IMGVOTER_IMAGES_DIR = external_images_dir)
  
  return(external_images_dir)
}

#' Check if a file is a symlink
#'
#' @param path Character. Path to check
#' @return Logical. TRUE if path is a symlink, FALSE otherwise
file.symlink.exists <- function(path) {
  if (!file.exists(path)) return(FALSE)
  # Use Sys.readlink to check if it's a symlink
  link_target <- Sys.readlink(path)
  return(!is.na(link_target) && link_target != "")
}

#' Initialize external server_data directory
#'
#' Creates and sets up the external server_data directory structure.
#'
#' @param base_dir Character. Base directory where server_data should be created
#' @return Character. Path to the created server_data directory
#' @export
init_external_server_data <- function(base_dir = getwd()) {
  server_data_dir <- file.path(base_dir, "server_data")
  
  if (!dir.exists(server_data_dir)) {
    dir.create(server_data_dir, recursive = TRUE)
    cat("Created external server_data directory at:", server_data_dir, "\n")
    
    # Create README for server_data
    readme_content <- "# Server Data Directory

This directory contains runtime server data for the B1MG Variant Voting application.

## Contents:
- Runtime logs
- Temporary files
- Session data
- Other server-side generated content

This directory is automatically created when the application starts.
"
    writeLines(readme_content, file.path(server_data_dir, "README.md"))
    
  } else {
    cat("External server_data directory already exists at:", server_data_dir, "\n")
  }
  
  return(server_data_dir)
}
