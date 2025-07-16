library(ShinyImgVoteR)
cfg <- ShinyImgVoteR::load_config()

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

print("Configuration loaded:")
print(cfg)

print("IMGVOTER_CURRENT_DIR:")
print(Sys.getenv("IMGVOTER_CURRENT_DIR"))

shiny::addResourcePath(
  prefix = "images",
  directoryPath = paste0(
    Sys.getenv("IMGVOTER_CURRENT_DIR"),
    cfg$images_dir
  )
)

# browser()

# GLOBAL pool object shared by all sessions
db_pool <- init_db(cfg$sqlite_file)

shiny::onStop(function() {
  if (inherits(db_pool, "Pool")) {
    pool::poolClose(db_pool)
  }
})

shiny::shinyApp(
  ui = votingAppUI(),
  server = makeVotingAppServer(db_pool)
)