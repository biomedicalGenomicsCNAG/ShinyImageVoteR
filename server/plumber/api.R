library(plumber)
library(tidyverse)
library(DBI)
library(RSQLite)
library(uuid)
library(jsonlite)
library(googlesheets4)
options(gargle_quiet = FALSE)
options(gargle_verbosity = "debug")

db <- dbConnect(SQLite(), "../db.sqlite")

gs4_auth(
  email = Sys.getenv("GOOGLE_SERVICE_ACC"),
  path = "gsheets_config.json"
)
cat("> confirm user name:")
gs4_user()

gdoc_base_url <- "https://docs.google.com/spreadsheets/d/"
drive_paths <- list(
  screenshots = paste0(gdoc_base_url, Sys.getenv("GDOCS_SCREENSHOTS_UID")),
  annotations = paste0(gdoc_base_url, Sys.getenv("GDOCS_ANNOTATIONS_UID"))
)
screenshots <- read_sheet(drive_paths$screenshots)
vartype_dict <- unique(screenshots$variant)

print(drive_paths)

choose_picture <- function(
    drive_paths,
    institute,
    training_questions,
    voting_institute,
    vartype,
    screenshots,
    vartype_dict,
    n_sample = 10) {
  print("in choose_picture")
  annot <- read_sheet(drive_paths$annotations) %>%
    # first N questions per centre are for training
    group_by(institute) %>%
    slice(-c(1:training_questions)) %>%
    ungroup() %>%
    # a row that will be removed but contains all agreement fields
    bind_rows(
      tibble(
        "image" = "-",
        already_voted = TRUE,
        agreement = c(
          "yes",
          "no",
          "diff_var",
          "not_confident"
        )
      )
    ) %>%
    # summarise if institute already voted
    group_by(image) %>%
    mutate(already_voted = (institute == voting_institute)) %>%
    mutate(already_voted = any(already_voted)) %>%
    count(image, already_voted, agreement) %>%
    spread(agreement, n, fill = 0) %>%
    mutate(total_votes = yes + no + diff_var + not_confident)

  print("> annot:")
  print(annot)

  # select candidates for random selection
  candidates <- screenshots %>%
    # pick the variants selected by the user
    filter((variant == vartype | !(vartype %in% vartype_dict))) %>%
    # get all images ids
    select(image, coordinates, path, REF, ALT, variant) %>%
    # add agreement info
    left_join(annot) %>%
    mutate(
      yes = coalesce(yes, 0),
      no = coalesce(no, 0),
      not_confident = coalesce(not_confident, 0),
      diff_var = coalesce(diff_var, 0),
      total_votes = coalesce(total_votes, 0),
      already_voted = coalesce(already_voted, FALSE)
    ) %>%
    # remove images if institute already voted
    # mutate(already_voted = !(is.na(already_voted) | !already_voted)) %>%
    filter(!already_voted) %>%
    # arrange(desc(total_votes)) %>%

    # filtering rules
    filter(!(yes >= 3 & yes / total_votes > 0.7)) %>%
    filter(!(no >= 3 & no / total_votes > 0.7))

  # subset a sample of screenshots
  if (!is.null(n_sample)) {
    if (nrow(candidates) < n_sample) {
      n_sample <- nrow(candidates)
    }
    candidates <- candidates %>%
      sample_n(size = n_sample)
  }

  print("> candidates:")
  print(candidates)
  candidates
}

#* @apiTitle Image Voting API
#* Get a random unvoted image
#* @get /api/images/next
#* @serializer json list(auto_unbox = TRUE)
function(req, res) {
  # SQL query to select the image with the fewest votes (ties broken randomly)
  # query <- "
  #   SELECT i.*
  #   FROM images i
  #   LEFT JOIN votes v ON i.id = v.image_id
  #   GROUP BY i.id
  #   ORDER BY COUNT(v.id), RANDOM()
  #   LIMIT 1
  # "

  # image <- dbGetQuery(db, query)

  # if (nrow(image) == 0) {
  #   res$status <- 404
  #   return(list(error = "No more images to vote on"))
  # }

  image <- choose_picture(
    drive_paths,
    training_questions = 10,
    voting_institute = "Training (answers won't be saved)",
    vartype = "All variants",
    screenshots = screenshots,
    vartype_dict = "SNV",
    n_sample = 10
  )

  print("Image selected:")
  print(image$path)

  # return a json response
  res <- list(
    id = image$image[1],
    url = image$path[1]
  )

  # res <- list(
  #   id = image$image[1],
  #   url = "https://omicsdm.cnag.dev/bucketdevelomicsdm/alex-perez-e6fwIVD0FYs-unsplash.jpg"
  # )

  res <- list(
    id = image$image[1],
    url = "https://lh3.googleusercontent.com/d/1GqYITqiyybwYOHFIDJh_gyVINUaY-VqR"
  )

  print("res:")
  print(res)

  # Return the image row as JSON
  return(res)
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
  rating <- body$rating

  # Validate rating
  if (rating < 1 || rating > 5) {
    res$status <- 500
    return(list(error = "Rating must be between 1 and 5"))
  }

  # Generate a UUID for the new vote
  id <- UUIDgenerate()

  # Insert the vote into the votes table
  sql <- "INSERT INTO votes (id, image_id, rating) VALUES (?, ?, ?)"

  tryCatch(
    {
      dbExecute(db, sql, params = list(id, image_id, rating))
      return(list(id = id, image_id = image_id, rating = rating))
    },
    error = function(e) {
      res$status <- 500
      return(list(error = "Failed to add vote"))
    }
  )
}
