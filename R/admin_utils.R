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

#' Reset user annotation file and update database vote counts
#'
#' Resets a user's annotation file by keeping the header row and the first
#' three columns (coordinates, REF, ALT) but clearing all other data columns.
#' Also updates the database by decrementing vote counts for all votes that
#' the user had cast. This allows a user to start voting from scratch while
#' preserving the randomized order of variants.
#'
#' @param annotation_file_path Character. Full path to the user's annotation TSV file
#' @param user_annotations_colnames Character vector. Column names for the annotation file
#' @param db_pool Database connection pool
#' @param cfg App configuration containing vote2dbcolumn_map
#'
#' @return Logical. TRUE if reset was successful, FALSE otherwise
#' @export
reset_user_annotations <- function(annotation_file_path, user_annotations_colnames, db_pool, cfg) {
  # Validate inputs
  if (!file.exists(annotation_file_path)) {
    warning("Annotation file does not exist: ", annotation_file_path)
    return(FALSE)
  }
  
  if (is.null(user_annotations_colnames) || length(user_annotations_colnames) == 0) {
    warning("user_annotations_colnames is NULL or empty")
    return(FALSE)
  }
  
  if (is.null(db_pool)) {
    warning("db_pool is NULL")
    return(FALSE)
  }
  
  if (is.null(cfg) || is.null(cfg$vote2dbcolumn_map)) {
    warning("cfg or cfg$vote2dbcolumn_map is NULL")
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
    
    # Update database vote counts by decrementing for each vote cast
    # Only process rows where agreement is not empty
    if ("agreement" %in% colnames(annotations_df)) {
      voted_rows <- annotations_df[!is.na(annotations_df$agreement) & 
                                   annotations_df$agreement != "", ]
      
      if (nrow(voted_rows) > 0) {
        message("Updating database vote counts for ", nrow(voted_rows), " voted variants")
        
        for (i in seq_len(nrow(voted_rows))) {
          agreement_val <- voted_rows$agreement[i]
          coord <- voted_rows$coordinates[i]
          ref_val <- voted_rows$REF[i]
          alt_val <- voted_rows$ALT[i]
          
          # Get the database column for this agreement value
          vote_col <- cfg$vote2dbcolumn_map[[agreement_val]]
          
          if (!is.null(vote_col) && vote_col != "") {
            # Decrement the vote count in the database
            db_update_query <- paste0(
              "UPDATE annotations SET ",
              vote_col,
              " = MAX(0, ",
              vote_col,
              " - 1) WHERE coordinates = ? AND REF = ? AND ALT = ?"
            )
            
            tryCatch({
              DBI::dbExecute(
                db_pool,
                db_update_query,
                params = list(coord, ref_val, alt_val)
              )
            }, error = function(e) {
              warning("Failed to update vote count for ", coord, ": ", e$message)
            })
          } else {
            warning("Could not find vote column for agreement: ", agreement_val)
          }
        }
        
        message("Successfully updated database vote counts")
      } else {
        message("No votes to decrement in database")
      }
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
