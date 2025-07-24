
if(any(grepl("posit.shiny", commandArgs(), fixed = TRUE)) && Sys.getenv("IMGVOTER_STARTED") != "1") {
  devtools::load_all("../..")  # Load from package root

  print("vscode-shiny detected -> delegating to app wrapper")

  Sys.setenv(IMGVOTER_STARTED = "1")
  
  # get the parent directory of the app
  app_dir <- normalizePath(dirname(commandArgs(trailingOnly = TRUE)[1]), mustWork = TRUE)
  # get two directories up
  app_env_dir <- normalizePath(file.path(app_dir, "../..", "app_env"), mustWork = TRUE)
  print(glue::glue("App directory: {app_dir}"))
  print(glue::glue("App environment directory: {app_env_dir}"))

  Sys.setenv(
    IMGVOTER_DB_PATH = file.path(app_env_dir, "db.sqlite"),
    IMGVOTER_IMAGES_DIR = file.path(app_env_dir, "images"),
    IMGVOTER_SERVER_DATA_DIR = file.path(app_env_dir, "server_data"),
    IMGVOTER_USER_DATA_DIR = file.path(app_env_dir, "user_data")
  )

  print("Environment variables set:")
  print(
    Sys.getenv(c(
      "IMGVOTER_DB_PATH", 
      "IMGVOTER_IMAGES_DIR", 
      "IMGVOTER_SERVER_DATA_DIR", 
      "IMGVOTER_USER_DATA_DIR"
    )
  ))

  # Run the wrapped app
  ShinyImgVoteR::run_voting_app(
    host = "127.0.0.1",
    port = as.integer(commandArgs(trailingOnly = TRUE)[2]),
    launch.browser = FALSE
  )
  quit(save = "no")
}

if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()  # Load from package root
} else {
  library(ShinyImgVoteR)
}

shiny::addResourcePath(
  prefix = "images",
  directoryPath = Sys.getenv("IMGVOTER_IMAGES_DIR")
)

# GLOBAL pool object shared by all sessions
db_pool <- init_db(Sys.getenv("IMGVOTER_DB_PATH"))

# shiny::onStop(function() {
#   if (inherits(db_pool, "Pool")) {
#     pool::poolClose(db_pool)
#   }
# })

shiny::shinyApp(
  ui = votingAppUI(),
  server = makeVotingAppServer(db_pool)
)