library(testthat)
library(plumber) # Will be used by tests

# This assumes that 'testthat.R' is run from the 'server/plumber/tests/' directory,
# or that the working directory is set appropriately for test_dir to find tests.
# If test_dir is called from a higher level (e.g., project root),
# it might be 'test_dir("server/plumber/tests/testthat")'

# For running tests when this file itself is sourced, e.g. Rscript server/plumber/tests/testthat.R
if (identical(sys.frame(), .GlobalEnv)) {
  # Ensure the working directory is 'server/plumber/tests' if running this file directly
  # This is a bit heuristic; robust test execution is usually handled by devtools::test() or similar.
  if (basename(getwd()) == "plumber" && basename(dirname(getwd())) == "server" ) {
     setwd("tests") # move into tests directory if in server/plumber
  } else if (basename(getwd()) != "tests" && file.exists("testthat.R") && file.exists("testthat")) {
    # Likely in server/plumber/tests already
  } else {
    warning("testthat.R might not be in the expected directory structure for setwd adjustments.")
  }

  # Check if 'testthat' subdirectory exists
  if(dir.exists("testthat")) {
    test_dir("testthat", reporter = "summary")
  } else {
    # If this file is in 'server/plumber/tests/testthat/', then test_dir should be "."
    # This is getting complicated. Standard test runners usually handle CWD better.
    # For now, let's assume it's run from server/plumber/tests
    # and the tests are in server/plumber/tests/testthat/
    # If this file itself is in testthat/, then test_dir(".")
    if (basename(getwd()) == "testthat" && basename(dirname(getwd())) == "tests"){
        test_dir(".", reporter = "summary")
    } else {
        message("Cannot determine correct directory for test_dir. Assuming tests are in a 'testthat' subdirectory from current WD.")
        test_dir("testthat", reporter = "summary") # Default assumption
    }
  }
}
