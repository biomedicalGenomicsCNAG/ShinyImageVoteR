library(plumber)
library(tidyverse)
library(DBI)
library(RSQLite)
library(uuid)
library(jsonlite)
library(googlesheets4)
options(gargle_quiet = FALSE)
options(gargle_verbosity = "debug")

# Attempt to connect to the database with error handling
db <- tryCatch({
  conn <- dbConnect(SQLite(), "../voting_app.db")
  message("INFO: Successfully connected to database '../voting_app.db'")
  conn
}, error = function(e) {
  message(sprintf("FATAL: Failed to connect to database '../voting_app.db': %s", e$message))
  # Stop execution if Plumber allows, or handle by returning a non-functional db object.
  # For Plumber, simply failing here might prevent the API from starting correctly.
  stop(sprintf("FATAL: Database connection failed: %s", e$message))
  # Or alternatively, to let Plumber start but have endpoints fail:
  # return(NULL)
})

# gs4_auth(
#   email = Sys.getenv("GOOGLE_SERVICE_ACC"),
#   path = "gsheets_config.json"
# )
# cat("> confirm user name:")
# gs4_user()

# gdoc_base_url <- "https://docs.google.com/spreadsheets/d/"
# drive_paths <- list(
#   screenshots = paste0(gdoc_base_url, Sys.getenv("GDOCS_SCREENSHOTS_UID")),
#   annotations = paste0(gdoc_base_url, Sys.getenv("GDOCS_ANNOTATIONS_UID"))
# )
# screenshots_gs <- read_sheet(drive_paths$screenshots) # Renamed to avoid conflict
# vartype_dict <- unique(screenshots_gs$variant)

# print(drive_paths)

choose_picture <- function(
    # drive_paths, # REMOVED: No longer reading from Google Sheets directly here
    institute,
    training_questions,
    voting_institute,
    vartype,
    # screenshots, # REMOVED: Will query from DB
    # vartype_dict, # REMOVED: vartype filtering can be done on DB query if needed
    n_sample = 10) {
  # Ensure db connection is valid before proceeding
  if (is.null(db) || !dbIsValid(db)) {
    message("ERROR: choose_picture - Database connection is not valid.")
    return(data.frame())
  }
  message("INFO: choose_picture called.")

  # Query screenshots from the database
  all_screenshots_db <- tryCatch({
    dbGetQuery(db, "SELECT id, coordinates, ref, alt, type_of_variant, path_to_screenshot, votes FROM screenshots")
  }, error = function(e) {
    message(sprintf("ERROR: choose_picture - Failed to query screenshots table: %s", e$message))
    return(data.frame()) # Return empty if query fails
  })

  if (nrow(all_screenshots_db) == 0) {
    message("INFO: choose_picture - No screenshots found in the database.")
    return(data.frame()) # Return empty data frame
  }

  # Filter candidates: select those with votes < 3
  candidates <- all_screenshots_db %>%
    filter(votes < 3)
  message(sprintf("INFO: choose_picture - Found %d candidates with votes < 3.", nrow(candidates)))

  # Commenting out previous complex filtering logic for now
  # annot <- read_sheet(drive_paths$annotations) %>%
  #   # first N questions per centre are for training
  #   group_by(institute) %>%
  #   slice(-c(1:training_questions)) %>%
  #   ungroup() %>%
  #   # a row that will be removed but contains all agreement fields
  #   bind_rows(
  #     tibble(
  #       "image" = "-", # This column needs to match the screenshot identifier if re-enabled
  #       already_voted = TRUE,
  #       agreement = c(
  #         "yes",
  #         "no",
  #         "diff_var",
  #         "not_confident"
  #       )
  #     )
  #   ) %>%
  #   # summarise if institute already voted
  #   group_by(image) %>%
  #   mutate(already_voted = (institute == voting_institute)) %>%
  #   mutate(already_voted = any(already_voted)) %>%
  #   count(image, already_voted, agreement) %>%
  #   spread(agreement, n, fill = 0) %>%
  #   mutate(total_votes_annot = yes + no + diff_var + not_confident) # Renamed to avoid conflict

  # print("> annot:")
  # print(annot)

  # # select candidates for random selection
  # candidates_old <- screenshots %>% # This was from Google Sheets
  #   # pick the variants selected by the user
  #   filter((variant == vartype | !(vartype %in% vartype_dict))) %>%
  #   # get all images ids
  #   select(image, coordinates, path, REF, ALT, variant) %>% # Ensure these column names match DB or are mapped
  #   # add agreement info
  #   left_join(annot, by = "image") %>% # Ensure 'image' column matches
  #   mutate(
  #     yes = coalesce(yes, 0),
  #     no = coalesce(no, 0),
  #     not_confident = coalesce(not_confident, 0),
  #     diff_var = coalesce(diff_var, 0),
  #     total_votes_annot = coalesce(total_votes_annot, 0),
  #     already_voted = coalesce(already_voted, FALSE)
  #   ) %>%
  #   # remove images if institute already voted
  #   filter(!already_voted) %>%
  #   # filtering rules (based on annotation agreement, currently not used)
  #   filter(!(yes >= 3 & yes / total_votes_annot > 0.7)) %>%
  #   filter(!(no >= 3 & no / total_votes_annot > 0.7))

  if (nrow(candidates) == 0) {
    print("No candidates with less than 3 votes.")
    return(data.frame()) # Return empty data frame
  }

  # subset a sample of screenshots
  if (!is.null(n_sample)) {
    if (nrow(candidates) < n_sample) {
      n_sample <- nrow(candidates)
    }
    # Ensure column names for sampling exist if this is used.
    # For now, path_to_screenshot and id are the key ones.
    candidates <- candidates %>%
      sample_n(size = n_sample)
  }

  print("> candidates selected:")
  # Ensure the column names used below (id, path_to_screenshot) exist in 'candidates'
  # If they are named differently from the DB query, adjust here.
  # For example, if dbGetQuery returns 'id' and 'path_to_screenshot'
  # print(select(candidates, id, path_to_screenshot, votes)) # Print relevant columns
  # print(candidates) # Reduce verbose logging of full candidate list unless debugging

  # The function needs to return a data frame with columns that will be used by the endpoint.
  # Let's ensure it returns 'id' and 'path_to_screenshot'
  return(candidates)
}

#* @apiTitle Image Voting API
#* Get a random unvoted image
#* @get /api/images/next
#* @serializer json list(auto_unbox = TRUE)
function(req, res) {
  message("INFO: /api/images/next endpoint called.")
  # Ensure db connection is valid before proceeding
  if (is.null(db) || !dbIsValid(db)) {
    message("ERROR: /api/images/next - Database connection is not valid.")
    res$status <- 503 # Service Unavailable
    return(list(error = "Database connection unavailable."))
  }

  # image <- choose_picture(
  #   drive_paths, # REMOVED
  #   training_questions = 10, # This and below params might be used for future complex logic
  #   voting_institute = "Training (answers won't be saved)",
  #   vartype = "All variants",
  #   # screenshots = screenshots, # REMOVED
  #   # vartype_dict = "SNV", # REMOVED
  #   n_sample = 1 # We need only one image for /next
  # )

  # Call choose_picture, requesting 1 sample.
  # The other parameters like institute, training_questions etc. are not strictly needed for the current logic
  # but are kept in function signature for potential future use.
  # For now, we can pass default/placeholder values if they are not used in the simplified choose_picture.
  image_data <- choose_picture(
    institute = "any", # Placeholder
    training_questions = 0, # Placeholder
    voting_institute = "any", # Placeholder
    vartype = "All", # Placeholder
    n_sample = 1
  )

  if (nrow(image_data) == 0) {
    message("INFO: /api/images/next - No image found by choose_picture (all images might have sufficient votes or DB is empty).")
    res$status <- 404
    return(list(error = "No more images to vote on or all images have received sufficient votes."))
  }

  # message("Image selected:") # Less verbose, specific log below
  # Assuming choose_picture returns 'id' and 'path_to_screenshot' from the database
  # print(image_data$path_to_screenshot[1])

  # return a json response
  # Ensure 'id' and 'path_to_screenshot' are present in image_data
  response_data <- list(
    id = image_data$id[1],
    url = image_data$path_to_screenshot[1]
  )
  message(sprintf("INFO: /api/images/next - Returning image ID: %s, Path: %s", response_data$id, response_data$url))

  # The following hardcoded URLs are now replaced by dynamic data
  # res <- list(
  #   id = image$image[1],
  #   url = "https://omicsdm.cnag.dev/bucketdevelomicsdm/alex-perez-e6fwIVD0FYs-unsplash.jpg"
  # )
  # res <- list(
  #   id = image$image[1],
  #   url = "https://lh3.googleusercontent.com/d/1GqYITqiyybwYOHFIDJh_gyVINUaY-VqR"
  # )

  print("res:")
  print(response_data)

  # Return the image row as JSON
  return(response_data)
}

#* @filter cors
cors <- function(res) {
    res$setHeader("Access-Control-Allow-Origin", "*")
    plumber::forward()
}

#* Add a vote for an image
#* @post /api/votes
#* @jserializer json
function(req, res) {
  # Parse the JSON request body
  body <- fromJSON(req$postBody)
  image_id <- body$image_id
  rating <- body$rating # rating can be NULL if not provided

  message(sprintf("INFO: /api/votes endpoint called for image_id: %s, rating: %s", image_id, ifelse(is.null(rating), "NULL", rating)))

  # Ensure db connection is valid
  if (is.null(db) || !dbIsValid(db)) {
    message("ERROR: /api/votes - Database connection is not valid.")
    res$status <- 503 # Service Unavailable
    return(list(error = "Database connection unavailable."))
  }

  # Validate image_id (basic check)
  if (is.null(image_id)) {
    message("ERROR: /api/votes - image_id is NULL.")
    res$status <- 400 # Bad request
    return(list(error = "image_id must be provided."))
  }

  # Validate rating
  if (!is.null(rating) && (rating < 1 || rating > 5)) {
    message(sprintf("ERROR: /api/votes - Invalid rating: %s for image_id: %s.", rating, image_id))
    res$status <- 400 # Bad request for invalid rating
    return(list(error = "Rating must be between 1 and 5 if provided"))
  }

  # Update vote count in the screenshots table
  message(sprintf("INFO: /api/votes - Attempting to update vote count for image_id: %s.", image_id))
  update_sql <- "UPDATE screenshots SET votes = votes + 1 WHERE id = ?"
  update_successful <- FALSE
  tryCatch({
    rows_affected <- dbExecute(db, update_sql, params = list(image_id))
    if (rows_affected > 0) {
      update_successful <- TRUE
      message(sprintf("INFO: /api/votes - Successfully updated vote count for image_id: %s. Rows affected: %d.", image_id, rows_affected))
    } else {
      message(sprintf("WARNING: /api/votes - No rows updated for image_id: %s. It might not exist.", image_id))
      # Potentially return 404 if image_id not found, but for now, we'll proceed to logging if rating exists
    }
  }, error = function(e) {
    message(sprintf("ERROR: /api/votes - Failed to update 'screenshots' table for image_id: %s: %s", image_id, e$message))
    res$status <- 500
    return(list(error = sprintf("Failed to update vote count for image_id %s.", image_id), details = e$message))
  })

  # If the primary update failed, return before attempting to log to 'votes' table
  if (res$status == 500) {
    return(list(error = sprintf("Failed to update vote count for image_id %s due to database error.", image_id)))
  }

  # Generate a UUID for the new vote (for the separate 'votes' log table)
  # This part can be kept if detailed vote logging is still desired.
  # Ensure 'image_id' here is the same as the one used for the screenshots table.
  log_id <- UUIDgenerate()

  # Insert the vote into the votes table (original detailed logging)
  # This table might store individual rating events, while `screenshots.votes` stores the aggregate.
  if (!is.null(rating)) {
    message(sprintf("INFO: /api/votes - Attempting to log detailed vote for image_id: %s with rating: %s.", image_id, rating))
    insert_log_sql <- "INSERT INTO votes (id, image_id, rating) VALUES (?, ?, ?)"
    tryCatch({
      dbExecute(db, insert_log_sql, params = list(log_id, image_id, rating))
      message(sprintf("INFO: /api/votes - Successfully logged detailed vote for image_id: %s, log_id: %s.", image_id, log_id))
      return(list(
        message = "Vote registered and logged successfully.",
        image_id = image_id,
        update_status = if(update_successful) "Screenshot vote count updated." else "Screenshot vote count NOT updated or image_id not found.",
        logged_vote_id = log_id,
        rating_logged = rating
      ))
    }, error = function(e_log) {
      message(sprintf("ERROR: /api/votes - Failed to log detailed vote to 'votes' table for image_id: %s: %s", image_id, e_log$message))
      # Return success for the main update if that happened, but with a warning about logging.
      res$status <- if(update_successful) 200 else 500 # If primary update failed, this is an error, otherwise it's a partial success
      return(list(
        message = if(update_successful) "Vote count updated, but failed to log detailed vote." else "Failed to update vote count AND failed to log detailed vote.",
        image_id = image_id,
        update_status = if(update_successful) "Screenshot vote count updated." else "Screenshot vote count FAILED or image_id not found.",
        logging_error = e_log$message
      ))
    })
  } else {
    message(sprintf("INFO: /api/votes - No rating provided for image_id: %s. Skipping detailed vote logging.", image_id))
    return(list(
      message = "Vote count updated successfully. No rating provided for detailed logging.",
      image_id = image_id,
      update_status = if(update_successful) "Screenshot vote count updated." else "Screenshot vote count NOT updated or image_id not found."
    ))
  }
}
