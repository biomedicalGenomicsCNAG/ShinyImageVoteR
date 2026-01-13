#' Initialize SQLite database
#'
#' @param db_path Character. Path to the SQLite database file to create
#' @param to_be_voted_images_file Character. Path to
#'                                the file containing image annotations
#' @param grouped_credentials List. Parsed YAML list of grouped credentials
#' @return Character path to the database file
#' @export
create_database <- function(
  db_path,
  to_be_voted_images_file,
  grouped_credentials
) {
  # Look for data file in config/annotation_screenshots_paths first
  db_full_path <- normalizePath(db_path)

  print(paste0("Creating database at:", db_path))

  # Create database structure
  conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_full_path)

  # Create annotations table

  # TODO
  # variant should be replaced by "mutation"

  # TODO
  # make the whole database generation more generic/configurable
  # so the ShinyImgVoteR can be applied to other use cases
  DBI::dbExecute(
    conn,
    "
    CREATE TABLE annotations (
      coordinates TEXT,
      REF TEXT,
      ALT TEXT,
      path TEXT,
      vote_count_correct INTEGER DEFAULT 0,
      vote_count_different_variant INTEGER DEFAULT 0,
      vote_count_germline INTEGER DEFAULT 0,
      vote_count_no_or_few_reads INTEGER DEFAULT 0,
      vote_count_none_of_above INTEGER DEFAULT 0,
      vote_count_total INTEGER DEFAULT 0
    )
  "
  )

  # Create trigger for vote total updates
  DBI::dbExecute(
    conn,
    "
    CREATE TRIGGER update_vote_total_update
    AFTER UPDATE ON annotations
    FOR EACH ROW
    BEGIN
      UPDATE annotations
      SET vote_count_total =
          vote_count_correct +
          vote_count_different_variant +
          vote_count_germline +
          vote_count_no_or_few_reads +
          vote_count_none_of_above
      WHERE rowid = NEW.rowid;
    END;
  "
  )

  DBI::dbExecute(
    conn,
    "
    CREATE TABLE sessionids (
      userid TEXT,
      sessionid TEXT,
      login_time TEXT,
      logout_time TEXT
    )
  "
  )

  DBI::dbExecute(
    conn,
    "
    CREATE TABLE passwords (
      userid TEXT PRIMARY KEY,
      admin BOOLEAN DEFAULT 0,
      institute TEXT,
      password TEXT,
      pwd_retrieval_token TEXT,
      pwd_retrieved_timestamp TEXT
    )
  "
  )

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
#'
#' @keywords internal
#'
#' @param conn Database connection object
#' @param to_be_voted_images_file Character. Path to the file containing image annotations
#' @return NULL
populate_annotations_table <- function(
  conn,
  to_be_voted_images_file
) {
  # Read the to_be_voted_images_file
  if (!file.exists(to_be_voted_images_file)) {
    stop("File not found: ", to_be_voted_images_file)
  }
  cat("Reading to_be_voted_images_file:", to_be_voted_images_file, "\n")

  # Read the file and create a data frame
  annotations_df <- read.table(
    to_be_voted_images_file,
    header = TRUE,
    stringsAsFactors = FALSE,
    colClasses = "character" # Otherwise the nucleotide T ends up as TRUE
  )

  print("First few rows of annotations_df:")
  print(head(annotations_df))

  first_path <- annotations_df$path[1]

  # Use dirname() to extract parent directories
  png_dir <- dirname(first_path) # directory containing PNGs
  parent_dir <- dirname(png_dir) # parent directory (one level up)
  cat("Detected PNG directory:", png_dir, "\n")
  cat("Detected parent directory:", parent_dir, "\n")

  annotations_df$path <- gsub(
    glue::glue("{parent_dir}/"),
    "",
    annotations_df$path
  )

  # Insert data into the annotations table
  DBI::dbWriteTable(
    conn,
    "annotations",
    annotations_df,
    append = TRUE,
    row.names = FALSE
  )
  cat("Populated annotations table with", nrow(annotations_df), "rows\n")
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
    is.null(x) ||
      length(x) == 0 ||
      is.na(x) ||
      identical(x, "") ||
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
    if (is.null(users)) {
      next
    }

    for (u in users) {
      uid <- nz_chr(u$userid)
      if (is.na(uid) || uid == "") {
        next
      }

      pw <- if (is_missing_pw(u$password)) {
        NA_character_
      } else {
        as.character(u$password)
      }
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

  cat(
    "Found users from config:",
    paste(unique(user_institute_map$userid), collapse = ", "),
    "\n"
  )

  # ---- Prepare data for insertion ----
  user_data <- data.frame(
    userid = user_institute_map$userid,
    institute = user_institute_map$institute,
    password = ifelse(
      is.na(user_institute_map$preset_password),
      vapply(
        user_institute_map$userid,
        function(x) generate_password(),
        character(1)
      ),
      user_institute_map$preset_password
    ),
    admin = as.integer(user_institute_map$admin), # store as 0/1 (portable)
    pwd_retrieval_token = sapply(
      user_institute_map$userid,
      function(x) digest::digest(paste0(x, Sys.time(), runif(1)))
    ),
    pwd_retrieved_timestamp = NA_character_,
    stringsAsFactors = FALSE
  )

  # ---- Insert ----
  DBI::dbWriteTable(conn, "passwords", user_data, append = TRUE)
  cat("Added", nrow(user_data), "users to the database\n")

  # ---- Display summary ----
  cat("\nAdded users and their passwords:\n")
  for (i in seq_len(nrow(user_data))) {
    cat(
      "User:",
      user_data$userid[i],
      "Institute:",
      user_data$institute[i],
      "Password:",
      user_data$password[i],
      "Admin:",
      as.logical(user_data$admin[i]),
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

#' Validate column names passed by config
#' Ensures that the columns specified in the configuration are safe
#' and exist in the database schema.
#' @param conn Database connection object
#' @param table Name of the table to validate against
#' @param cfg_db_cols Character vector of column names from config
#' @return A character vector of validated column names
#' @export
validate_cols <- function(conn, table, cfg_db_cols) {
  # Read from config
  cols <- cfg_db_cols
  if (is.null(cols) || !length(cols)) {
    stop("Config 'db_general_cols' is missing or empty.")
  }

  # 1) Basic identifier hygiene: only ASCII letters, digits,
  #    underscore; must start with letter/underscore
  is_safe_ident <- function(x) grepl("^[A-Za-z_][A-Za-z0-9_]*$", x, perl = TRUE)

  # 2) SQLite keyword blocklist (generated with GPT-5)
  SQLITE_KEYWORDS <- c(
    "ABORT",
    "ACTION",
    "ADD",
    "AFTER",
    "ALL",
    "ALTER",
    "ANALYZE",
    "AND",
    "AS",
    "ASC",
    "ATTACH",
    "AUTOINCREMENT",
    "BEFORE",
    "BEGIN",
    "BETWEEN",
    "BY",
    "CASCADE",
    "CASE",
    "CAST",
    "CHECK",
    "COLLATE",
    "COLUMN",
    "COMMIT",
    "CONFLICT",
    "CONSTRAINT",
    "CREATE",
    "CROSS",
    "CURRENT",
    "CURRENT_DATE",
    "CURRENT_TIME",
    "CURRENT_TIMESTAMP",
    "DATABASE",
    "DEFAULT",
    "DEFERRABLE",
    "DEFERRED",
    "DELETE",
    "DESC",
    "DETACH",
    "DISTINCT",
    "DO",
    "DROP",
    "EACH",
    "ELSE",
    "END",
    "ESCAPE",
    "EXCEPT",
    "EXCLUSIVE",
    "EXISTS",
    "EXPLAIN",
    "FAIL",
    "FOR",
    "FOREIGN",
    "FROM",
    "FULL",
    "GLOB",
    "GROUP",
    "HAVING",
    "IF",
    "IGNORE",
    "IMMEDIATE",
    "IN",
    "INDEX",
    "INDEXED",
    "INITIALLY",
    "INNER",
    "INSERT",
    "INSTEAD",
    "INTERSECT",
    "INTO",
    "IS",
    "ISNULL",
    "JOIN",
    "KEY",
    "LEFT",
    "LIKE",
    "LIMIT",
    "MATCH",
    "NATURAL",
    "NO",
    "NOT",
    "NOTNULL",
    "NULL",
    "OF",
    "OFFSET",
    "ON",
    "OR",
    "ORDER",
    "OUTER",
    "PLAN",
    "PRAGMA",
    "PRIMARY",
    "QUERY",
    "RAISE",
    "RECURSIVE",
    "REFERENCES",
    "REGEXP",
    "REINDEX",
    "RELEASE",
    "RENAME",
    "REPLACE",
    "RESTRICT",
    "RIGHT",
    "ROLLBACK",
    "ROW",
    "SAVEPOINT",
    "SELECT",
    "SET",
    "TABLE",
    "TEMP",
    "TEMPORARY",
    "THEN",
    "TO",
    "TRANSACTION",
    "TRIGGER",
    "UNION",
    "UNIQUE",
    "UPDATE",
    "USING",
    "VACUUM",
    "VALUES",
    "VIEW",
    "VIRTUAL",
    "WHEN",
    "WHERE",
    "WITH",
    "WITHOUT"
  )
  is_keyword <- function(x) toupper(x) %in% SQLITE_KEYWORDS

  # 3) Ensure columns exist in the DB schema for the target table
  db_cols <- tryCatch(
    DBI::dbListFields(conn, table),
    error = function(e) character()
  )
  if (!length(db_cols)) {
    stop(glue::glue("Could not introspect columns for table '{table}'."))
  }

  # validation
  bad_ident <- cols[!is_safe_ident(cols)]
  bad_kw <- cols[is_keyword(cols)]
  missing <- setdiff(cols, db_cols)

  if (length(bad_ident) || length(bad_kw) || length(missing)) {
    problems <- c(
      if (length(bad_ident)) {
        glue::glue("Invalid identifiers: {paste(bad_ident, collapse = ', ')}")
      },
      if (length(bad_kw)) {
        glue::glue("Disallowed keywords: {paste(bad_kw, collapse = ', ')}")
      },
      if (length(missing)) {
        glue::glue(
          "Not present in table '{table}': {paste(missing, collapse = ', ')}"
        )
      }
    )
    stop(
      glue::glue(
        "Column validation failed: {paste(problems, collapse = ' | ')}"
      )
    )
  }
  TRUE
}

#' Query annotations table by coordinates and optionally REF/ALT
#' This function queries the annotations table for a given set of coordinates,
#' returning only the specified columns. Optionally filters by REF and ALT
#' to handle cases where coordinates alone are not unique.
#' @param conn Database connection object
#' @param coord Character. The coordinates to query (exact match)
#' @param cols Character vector. The columns to retrieve
#' @param ref Character. Optional REF allele to query (exact match)
#' @param alt Character. Optional ALT allele to query (exact match)
#' @param query_keys Character vector. Optional query keys to use for filtering.
#'   If not provided, defaults to c("coordinates", "REF", "ALT") if ref and alt
#'   are provided, otherwise just "coordinates".
#' @return A data frame with the query results
query_annotations_db_by_coord <- function(
  conn,
  coord,
  cols,
  ref = NULL,
  alt = NULL,
  query_keys = NULL
) {
  table <- tolower("annotations") # only one table for now

  # 1) enforce exactly one coordinate (scalar, not vector/list, not NA)
  if (length(coord) != 1 || is.list(coord) || is.null(coord) || anyNA(coord)) {
    stop(glue::glue(
      "Exactly one coordinate expected. Got length={length(coord)}."
    ))
  }

  # 2) Determine which query keys to use
  if (is.null(query_keys)) {
    # Default behavior: if ref and alt provided, use all three keys
    if (!is.null(ref) && !is.null(alt)) {
      query_keys <- c("coordinates", "REF", "ALT")
    } else {
      query_keys <- c("coordinates")
    }
  }

  # 3) Build WHERE clause based on query_keys
  where_clauses <- c()
  params <- list()

  if ("coordinates" %in% query_keys) {
    where_clauses <- c(
      where_clauses,
      paste0(DBI::dbQuoteIdentifier(conn, "coordinates"), " = ?")
    )
    params <- c(params, list(coord))
  }

  if ("REF" %in% query_keys) {
    if (is.null(ref)) {
      stop("REF is in query_keys but ref parameter is NULL")
    }
    where_clauses <- c(
      where_clauses,
      paste0(DBI::dbQuoteIdentifier(conn, "REF"), " = ?")
    )
    params <- c(params, list(ref))
  }

  if ("ALT" %in% query_keys) {
    if (is.null(alt)) {
      stop("ALT is in query_keys but alt parameter is NULL")
    }
    where_clauses <- c(
      where_clauses,
      paste0(DBI::dbQuoteIdentifier(conn, "ALT"), " = ?")
    )
    params <- c(params, list(alt))
  }

  # 4) quote identifiers for SELECT columns
  q_cols <- DBI::dbQuoteIdentifier(conn, unique(cols))
  q_table <- DBI::dbQuoteIdentifier(conn, table)

  # 5) build + execute query
  sql <- paste0(
    "SELECT rowid, ",
    paste(q_cols, collapse = ", "),
    " FROM ",
    q_table,
    " WHERE ",
    paste(where_clauses, collapse = " AND ")
  )

  result <- DBI::dbGetQuery(conn, sql, params = params)

  # 6) enforce at most one result row
  if (nrow(result) > 1) {
    key_info <- paste(
      "coordinates =",
      coord,
      if (!is.null(ref)) paste(", REF =", ref) else "",
      if (!is.null(alt)) paste(", ALT =", alt) else ""
    )
    stop(glue::glue(
      "Expected at most 1 row for {key_info}, got {nrow(result)} rows."
    ))
  }
  result
}
