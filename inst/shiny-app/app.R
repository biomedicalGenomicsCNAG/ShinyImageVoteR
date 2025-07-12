library(B1MGVariantVoting)
cfg <- B1MGVariantVoting::load_config()

shinyApp(
  ui = votingAppUI(),
  server = makeVotingAppServer(init_db(cfg$sqlite_file))
)