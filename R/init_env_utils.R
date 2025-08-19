#' Copy a directory from the app to a target path
#' This function copies a directory from the app's default environment to a specified target path.
#'
#' @keywords internal
#' @param target_dir_path Character. Path to the target directory where the app directory will be copied.
#'
#' @return Character path to the copied directory
copy_dir_from_app <- function(target_dir_path) {
  app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

  target_dir_name <- basename(target_dir_path)
  dir_to_copy <- file.path(app_dir, "default_env", target_dir_name)

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

#' Create a Directory Safely
#'
#' Validates that the target directory name is a single “word” (letters, digits, and/or underscores only)
#' before attempting to create it. Optionally handles nested creation, warnings, and permission bits.
#'
#' @param path Character. The name (or path) of the directory to create.
#'        Only the final component (basename) is validated.
#' @param pattern Character. A regular expression that the directory name must match.
#'        Default is `"^[A-Za-z0-9_]+$"`, i.e. one or more letters, digits, or underscores.
#' @param showWarnings Logical. If `TRUE`, warns when the directory already exists or cannot be created.
#'        Default is `TRUE`.
#' @param recursive Logical. If `TRUE`, creates any missing parent directories (like `mkdir -p`). Default is `FALSE`.
#' @param mode Character or numeric. Directory permissions in octal (e.g. `"0777"`). Default is `"0777"`.
#'
#' @return Invisibly returns `TRUE` if the directory was successfully created, `FALSE` otherwise.
#'         If the directory already exists, returns `FALSE` (with a message, unless `showWarnings = FALSE`).
#'
#' @examples
#' # Successful creation
#' safe_dir_create("data_folder")
#'
#' # Fails validation (contains spaces)
#' try(safe_dir_create("my data"))
safe_dir_create <- function(
    path,
    pattern = "^[A-Za-z0-9_]+$",
    showWarnings = TRUE,
    recursive = FALSE) {
  name <- basename(path)

  # Validate against the pattern
  if (!grepl(pattern, name)) {
    stop(
      "Invalid directory name: '", name,
      "'. Only letters, digits and underscores are allowed."
    )
  }

  # If it already exists, warn or message and return FALSE
  if (dir.exists(path)) {
    if (showWarnings) {
      message("Directory '", path, "' already exists.")
    }
    return(invisible(FALSE))
  }

  # Create the directory
  dir.create(
    path,
    showWarnings = showWarnings,
    recursive = recursive
  )
}

# Ensure that .gitignore in dir contains the given patterns
#'
#' This function checks if a .gitignore file exists in the specified directory.
#' If it does not exist, it creates one. It then ensures that the specified patterns
#' are present in the .gitignore file, adding them if they are missing.
#'
#' @keywords internal
#' @param dir Character. Directory path where the .gitignore file should be checked/created.
#' @param patterns Character vector. Patterns to ensure in the .gitignore file.
#'
#' @return Character path to the .gitignore file
#'
ensure_gitignore <- function(directory, patterns) {
  dir_full_path <- normalizePath(directory, mustWork = TRUE)
  gi_path <- file.path(dir_full_path, ".gitignore")

  existing <- character(0)
  if (file.exists(gi_path)) {
    existing <- readLines(gi_path, warn = FALSE)
    message(glue::glue("Found existing .gitignore at {gi_path}"))
  }

  # Determine which patterns are missing
  missing <- setdiff(patterns, existing)
  message(glue::glue(
    "Checking .gitignore in {dir_full_path} for patterns: {paste(patterns, collapse=', ')}"
  ))
  message("missing patterns:")
  print(missing)
  if (length(missing) > 0) {
    new_contents <- c(existing, missing)
    writeLines(new_contents, gi_path)
    tryCatch(
      {
        message(glue::glue(
          "Added {length(missing)} pattern{?s} to .gitignore:",
          "{?s,}{paste(missing, collapse=', ')}"
        ))
      },
      error = function(e) {
        # Handle the error—e$message contains the error text
        message("Failed to explain .gitignore updates: ", e$message)
        # You could also stop(), warning(), or take other recovery actions here
      }
    )
  } else {
    message("All specified patterns already present in .gitignore.")
  }

  invisible(gi_path)
}

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

#' Generate a password retrieval link
#'
#' Creates a query string containing the provided token. The resulting string
#' can be appended to a URL so that the token is available as a query
#' parameter.
#'
#' @param token Character. Password retrieval token.
#'
#' @return Character string of the form `?token=<token>`
generate_password_retrieval_link <- function(userid) {
  token <- digest::digest(paste0(userid, Sys.time(), runif(1)))
  paste0("?token=", token)
}

#' Retrieve a password using a retrieval token
#'
#' Looks up the password corresponding to a retrieval link token and marks the
#' link as shown in the database.
#'
#' @param token Character. Retrieval token from the URL path.
#' @param conn Database connection object.
#' @return Character password if token is valid, otherwise NULL.
#' @keywords internal
retrieve_password_from_link <- function(token, conn) {
  print("In retrieve_password_from_link")
  print("token")
  print(token)
  res <- DBI::dbGetQuery(conn,
    "SELECT userid, password FROM passwords WHERE password_retrieval_link = ?",
    params = list(token)
  )
  if (nrow(res) == 0) {
    return(NULL)
  }
  DBI::dbExecute(conn,
    "UPDATE passwords SET link_clicked_timestamp = ?, WHERE password_retrieval_link = ?",
    params = list(as.character(Sys.time()), token)
  )
  res$password[[1]]
}
