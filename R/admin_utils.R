# coalescing operator: return `a` if it exists and is non-empty,
# otherwise fall back to `b`.
`%||%` <- function(a, b) {
  # If `a` is NULL, there is nothing to return
  if (is.null(a)) {
    return(b)
  }

  # If `a` is a character but empty ("") or all whitespace, also use `b`
  if (is.character(a) && !nzchar(a)) {
    return(b)
  }

  # Otherwise keep the original value
  a
}


#' Build base URL from session data, accounting for reverse proxy subpaths
#'
#' @param session Shiny session object
#' @return Complete base URL including protocol, host, port, and pathname
#' @export
build_base_url <- function(session) {
  # 1) Protocol from the browser, not guessed from port
  proto_raw <- session$clientData$url_protocol %||% "https:"
  proto <- sub(":$", "", tolower(proto_raw)) # "http:" -> "http"

  # 2) Hostname
  host <- session$clientData$url_hostname %||% "localhost"

  # 3) Port: include only if present and non-default for the protocol
  port_val <- session$clientData$url_port
  port_part <- ""
  if (!is.null(port_val) && nzchar(as.character(port_val))) {
    port_num <- suppressWarnings(as.integer(port_val))
    is_default <- (proto == "http" && identical(port_num, 80L)) ||
      (proto == "https" && identical(port_num, 443L))
    if (!is_default) port_part <- paste0(":", port_val)
  }

  # 4) Pathname: keep subpath, drop query, normalize trailing slash
  pathname <- session$clientData$url_pathname %||% "/"
  pathname <- sub("\\?.*$", "", pathname)
  if (!nzchar(pathname)) pathname <- "/"
  if (!grepl("/$", pathname)) pathname <- paste0(pathname, "/")

  paste0(proto, "://", host, port_part, pathname)
}

#' Reset user annotation file
#'
#' Resets a user's annotation file by keeping the header row and the first
#' three columns (coordinates, REF, ALT) but clearing all other data columns.
#' This allows a user to start voting from scratch while preserving the
#' randomized order of variants.
#'
#' @param annotation_file_path Character. Full path to the user's annotation TSV file
#' @param user_annotations_colnames Character vector. Column names for the annotation file
#'
#' @return Logical. TRUE if reset was successful, FALSE otherwise
#' @export
reset_user_annotations <- function(annotation_file_path, user_annotations_colnames) {
  # Validate inputs
  if (!file.exists(annotation_file_path)) {
    warning("Annotation file does not exist: ", annotation_file_path)
    return(FALSE)
  }
  
  if (is.null(user_annotations_colnames) || length(user_annotations_colnames) == 0) {
    warning("user_annotations_colnames is NULL or empty")
    return(FALSE)
  }
  
  tryCatch({
    # Read the existing annotation file
    annotations_df <- read.table(
      annotation_file_path,
      sep = "\t",
      header = TRUE,
      stringsAsFactors = FALSE,
      quote = "",
      comment.char = ""
    )
    
    # Verify that the file has the expected columns
    if (!all(c("coordinates", "REF", "ALT") %in% colnames(annotations_df))) {
      warning("Annotation file is missing required columns (coordinates, REF, ALT)")
      return(FALSE)
    }
    
    # Create a new data frame with the same structure
    # Keep coordinates, REF, ALT, but reset all other columns to empty strings
    reset_df <- setNames(
      as.data.frame(
        lapply(user_annotations_colnames, function(col) {
          if (col %in% c("coordinates", "REF", "ALT")) {
            annotations_df[[col]]
          } else {
            rep("", nrow(annotations_df))
          }
        }),
        stringsAsFactors = FALSE
      ),
      user_annotations_colnames
    )
    
    # Write the reset data back to the file
    write.table(
      reset_df,
      file = annotation_file_path,
      sep = "\t",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE
    )
    
    message("Successfully reset annotations for file: ", annotation_file_path)
    return(TRUE)
  }, error = function(e) {
    warning("Failed to reset annotations: ", e$message)
    return(FALSE)
  })
}
