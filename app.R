# script to run the app with shiny-server
renv::install("ShinyImgVoteR_0.1.2.tar.gz")
library(ShinyImgVoteR)

# for shiny server deployment
host <- Sys.getenv("SHINY_HOST", "0.0.0.0")
port <- as.integer(Sys.getenv("SHINY_PORT", 3838))

ShinyImgVoteR::run_voting_app(
  host = host,
  port = port,
  launch.browser = FALSE
)
