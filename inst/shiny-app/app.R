library(ShinyImgVoteR)

if(any(grepl("posit.shiny", commandArgs(), fixed = TRUE)) && Sys.getenv("IMGVOTER_STARTED") != "1") {
  print("vscode-shiny detected -> delegating to app wrapper")

  Sys.setenv(IMGVOTER_STARTED = "1")
  
  # Run the wrapped app
  ShinyImgVoteR::run_voting_app(
    host = "127.0.0.1",
    port = as.integer(commandArgs(trailingOnly = TRUE)[2]),
    launch.browser = FALSE
  )
  quit(save = "no")
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