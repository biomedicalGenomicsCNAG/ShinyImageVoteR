library(shiny)

# Helper to set up a test environment and annotations file
setup_voting_env <- function(coordinates) {
  temp_dir <- tempdir()
  test_user_data_dir <- file.path(temp_dir, "test_user_data")
  dir.create(test_user_data_dir, recursive = TRUE, showWarnings = FALSE)

  test_annotations_file <- file.path(test_user_data_dir, "test_annotations.txt")
  test_annotations <- data.frame(
    coordinates = coordinates,
    agreement = "",
    alternative_vartype = "",
    observation = "",
    comment = "",
    shinyauthr_session_id = "",
    time_till_vote_casted_in_seconds = NA,
    stringsAsFactors = FALSE
  )
  write.table(
    test_annotations, test_annotations_file, sep = "\t",
    row.names = FALSE, col.names = TRUE, quote = FALSE
  )

  list(
    data_dir = test_user_data_dir,
    annotations_file = test_annotations_file
  )
}

# Common args for server initialization
make_args <- function(annotations_file) {
  list(
    id = "voting",
    login_trigger = reactiveVal(
      list(user_id = "test_user", voting_institute = "CNAG")
    ),
    get_mutation_trigger_source = reactiveVal(NULL)
  )
}