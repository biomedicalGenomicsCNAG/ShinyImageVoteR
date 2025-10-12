library(shiny)

# Helper to set up a test environment and annotations file
setup_voting_env <- function(coordinates) {
  temp_dir <- tempdir()
  test_user_data_dir <- file.path(temp_dir, "test_user_data")
  dir.create(test_user_data_dir, recursive = TRUE, showWarnings = FALSE)

  test_annotations_file <- file.path(test_user_data_dir, "test_annotations.txt")

  # check if alternative_vartype is still in use
  test_annotations <- data.frame(
    coordinates = coordinates,
    agreement = "",
    alternative_vartype = "",
    observation = "",
    comment = "",
    shinyauthr_session_id = "",
    time_till_vote_casted_in_seconds = "",
    stringsAsFactors = FALSE
  )

  write.table(
    test_annotations, test_annotations_file,
    sep = "\t",
    row.names = FALSE, col.names = TRUE, quote = FALSE
  )

  list(
    data_dir = test_user_data_dir,
    annotations_file = test_annotations_file
  )
}

# Common args for server initialization
make_args <- function(annotations_file) {
  # Create mock database but don't set it globally yet
  mock_db <- create_mock_db()

  # Create the argument list that votingServer expects
  args <- list(
    id = "voting",
    db_pool = mock_db$pool,
    login_trigger = shiny::reactiveVal(
      list(user_id = "test_user", voting_institute = "CNAG")
    ),
    get_mutation_trigger_source = shiny::reactiveVal(NULL)
  )

  # Attach mock_db as an attribute for cleanup purposes
  attr(args, "mock_db") <- mock_db

  return(args)
}

# Helper function to set up database globally and return cleanup function
setup_test_db <- function(args) {
  # Extract mock_db from the attributes
  mock_db <- attr(args, "mock_db")

  # Set the global db_pool that the module expects
  db_pool <<- mock_db$pool

  # Return cleanup function
  function() {
    pool::poolClose(mock_db$pool)
    unlink(mock_db$file)
  }
}
