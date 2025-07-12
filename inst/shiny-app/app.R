library(B1MGVariantVoting)

shinyApp(
  ui = votingAppUI(),
  server = makeVotingAppServer(init_db(cfg_sqlite_file))
)