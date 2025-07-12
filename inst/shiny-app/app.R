library(B1MGVariantVoting)
cfg <- B1MGVariantVoting::load_config()

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