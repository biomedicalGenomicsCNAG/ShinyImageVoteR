#' Initialize external database
#'
#' Sets up the SQLite database file outside the package using the same logic as init_db.R.
#'
#' @param base_dir Character. Base directory for database (default: current working directory)
#' @param db_name Character. Name of the database file (default: "db.sqlite")
#' @return Character path to the database file
#' @export
create_database <- function(
    db_path,
    to_be_voted_images_file,
    grouped_credentials) {
  # Look for data file in config/annotation_screenshots_paths first
  config_data_file <- to_be_voted_images_file
  db_full_path <- normalizePath(db_path)

  print(paste0("Creating database at:", db_path))

  # Create database structure
  conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_full_path)

  DBI::dbExecute(conn, "
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

  # Create trigger for vote total updates
  DBI::dbExecute(conn, "
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

  DBI::dbExecute(conn, "
    CREATE TABLE sessionids (
      userid TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  ")

  DBI::dbExecute(conn, "
    CREATE TABLE passwords (
      userid TEXT PRIMARY KEY,
      admin BOOLEAN DEFAULT 0,
      institute TEXT,
      password TEXT,
      password_retrieval_link TEXT,
      link_clicked_timestamp TEXT
    )
  ")

  populate_annotations_table(
    conn,
    to_be_voted_images_file
  )

  populate_users_table(
    conn,
    grouped_credentials
  )

  DBI::dbDisconnect(conn)
  return(normalizePath(db_path))
}

#' Populate the annotations table with data from a file
#'
#' @keywords internal
#'
#' @param conn Database connection object
#' @param to_be_voted_images_file Character. Path to the file containing image annotations
#' @return NULL
populate_annotations_table <- function(
    conn,
    to_be_voted_images_file) {
  # Read the to_be_voted_images_file
  if (!file.exists(to_be_voted_images_file)) {
    stop("File not found: ", to_be_voted_images_file)
  }

  cat("Reading to_be_voted_images_file:", to_be_voted_images_file, "\n")

  # Read the file and create a data frame
  annotations_df <- read.table(
    to_be_voted_images_file,
    header = FALSE,
    stringsAsFactors = FALSE
  )

  # TODO
  # This should be not hardcoded but read from the config file
  colnames(annotations_df) <- c("coordinates", "REF", "ALT", "variant", "path")

  # TODO
  # This should be not hardcoded but read from the config file
  annotations_df$path <- gsub(
    "/vol/b1mg/", "images/",
    annotations_df$path
  )

  # Insert data into the annotations table
  DBI::dbWriteTable(
    conn, "annotations", annotations_df,
    append = TRUE, row.names = FALSE
  )
  cat("Populated annotations table with", nrow(annotations_df), "rows\n")
}

#' Populate the users table with data from the grouped credentials file
#' @keywords internal
#' @param conn Database connection object
#' @param grouped_credentials Object. Loaded grouped credentials from the config file
#' @return NULL
populate_users_table_old <- function(
    conn,
    grouped_credentials) {
  cat("Found grouped_credentials_file, populating users...\n")

  # Extract all userids with their institutes and preset passwords
  user_institute_map <- data.frame(
    userid = character(0),
    institute = character(0),
    preset_password = character(0),
    stringsAsFactors = FALSE
  )

  for (institute in names(grouped_credentials)) {
    users <- grouped_credentials[[institute]]

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

  # Insert users
  DBI::dbWriteTable(conn, "passwords", user_data, append = TRUE)
  cat("Added", nrow(user_data), "users to the database\n")

  # Display the added users and their passwords
  cat("\nAdded users and their passwords:\n")
  for (i in 1:nrow(user_data)) {
    cat("User:", user_data$userid[i], "Institute:", user_data$institute[i], "Password:", user_data$password[i], "\n")
  }
}

#' Populate the users table with data from grouped credentials (per-institute lists)
#'
#' Expected YAML shape:
#' <institute_name>:
#'   - userid: <user>
#'     password: <string>|NULL
#'     admin: true|false  # optional
#'
#' Columns written: userid, institute, password, admin, password_retrieval_link, link_clicked_timestamp
#'
#' @keywords internal
#' @param conn Database connection object
#' @param grouped_credentials list; parsed YAML
#' @return NULL
populate_users_table <- function(conn, grouped_credentials) {
  cat("Found grouped_credentials_file, populating users...\n")

  # ---- Helpers ----
  nz_chr <- function(x) {
    if (is.null(x) || (is.character(x) && length(x) == 0)) {
      return(NA_character_)
    }
    as.character(x)
  }
  is_missing_pw <- function(x) {
    # Treat NULL, NA, "", or literal "NULL" as missing
    is.null(x) || length(x) == 0 || is.na(x) || identical(x, "") ||
      (is.character(x) && toupper(x) == "NULL")
  }
  nz_lgl <- function(x, default = FALSE) {
    if (is.null(x) || length(x) == 0 || is.na(x)) {
      return(default)
    }
    as.logical(x)
  }

  # ---- Build rows from all institutes ----
  user_institute_map <- data.frame(
    userid = character(0),
    institute = character(0),
    preset_password = character(0),
    admin = logical(0),
    stringsAsFactors = FALSE
  )

  institutes <- names(grouped_credentials)
  for (institute in institutes) {
    users <- grouped_credentials[[institute]]
    if (is.null(users)) next

    for (u in users) {
      uid <- nz_chr(u$userid)
      if (is.na(uid) || uid == "") next

      pw <- if (is_missing_pw(u$password)) NA_character_ else as.character(u$password)
      adm <- nz_lgl(u$admin, default = FALSE)

      user_institute_map <- rbind(
        user_institute_map,
        data.frame(
          userid = uid,
          institute = institute,
          preset_password = pw,
          admin = adm,
          stringsAsFactors = FALSE
        )
      )
    }
  }

  if (nrow(user_institute_map) == 0) {
    cat("No users found in config.\n")
    return(invisible(NULL))
  }

  cat("Found users from config:", paste(unique(user_institute_map$userid), collapse = ", "), "\n")

  # ---- Prepare data for insertion ----
  user_data <- data.frame(
    userid = user_institute_map$userid,
    institute = user_institute_map$institute,
    password = ifelse(
      is.na(user_institute_map$preset_password),
      vapply(user_institute_map$userid, function(x) generate_password(), character(1)),
      user_institute_map$preset_password
    ),
    admin = as.integer(user_institute_map$admin), # store as 0/1 (portable)
    password_retrieval_link = NA_character_,
    link_clicked_timestamp = NA_character_,
    stringsAsFactors = FALSE
  )

  # ---- Insert ----
  DBI::dbWriteTable(conn, "passwords", user_data, append = TRUE)
  cat("Added", nrow(user_data), "users to the database\n")

  # ---- Display summary ----
  cat("\nAdded users and their passwords:\n")
  for (i in seq_len(nrow(user_data))) {
    cat(
      "User:", user_data$userid[i],
      "Institute:", user_data$institute[i],
      "Password:", user_data$password[i],
      "Admin:", as.logical(user_data$admin[i]),
      "\n"
    )
  }

  invisible(NULL)
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
