library(ShinyImgVoteR)
cfg <- ShinyImgVoteR::load_config()

print("Configuration loaded:")
print(cfg)

print("IMGVOTER_CURRENT_DIR:")
print(Sys.getenv("IMGVOTER_CURRENT_DIR"))

# sanitise

shiny::addResourcePath(
  prefix = "images",
  directoryPath = paste0(
    Sys.getenv("IMGVOTER_CURRENT_DIR"),
    cfg$images_dir
  )
)

# GLOBAL pool object shared by all sessions
db_pool <- init_db(cfg$sqlite_file)

onStop(function() {
  if (inherits(db_pool, "Pool")) {
    pool::poolClose(db_pool)
  }
})

shinyApp(
  ui = votingAppUI(),
  server = makeVotingAppServer(db_pool)
)