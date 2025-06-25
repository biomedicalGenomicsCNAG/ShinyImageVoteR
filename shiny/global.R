onStop(function() {
  cat("App stopping — updating end_time for any open sessions in all user_info files\n")

  base_dir <- "user_data"
  # find every file ending in _info.json anywhere beneath user_data/
  info_files <- list.files(
    path      = base_dir,
    pattern   = "_info\\.json$",
    recursive = TRUE,
    full.names= TRUE
  )

  now_str <- as.character(Sys.time())

  for (f in info_files) {
  # read the file
  user_info <- tryCatch(
    read_json(f),
    error = function(e) {
    warning("Failed to read ", f, ": ", e$message)
    return(NULL)
    }
  )
  if (is.null(user_info)) next

  # update any sessions with end_time == NULL
  updated <- FALSE
  for (token in names(user_info$sessions)) {
    sess <- user_info$sessions[[token]]
    if (is.null(sess$end_time)) {
    user_info$sessions[[token]]$end_time <- now_str
    updated <- TRUE
    }
  }

  # write back only if we changed something
  if (updated) {
      tryCatch(
      write_json(user_info, f, auto_unbox = TRUE, pretty = TRUE),
      error = function(e) {
        warning("Failed to write ", f, ": ", e$message)
      })
      cat("  • Updated end_time in", f, "\n")
  }}
  cat("All done at", now_str, "\n")
})
  