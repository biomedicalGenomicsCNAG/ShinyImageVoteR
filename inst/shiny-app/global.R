library(pool)
library(RSQLite)

app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")
source(file.path(app_dir, "config.R"))

source(file.path(app_dir, "modules", "login_module.R"))
source(file.path(app_dir, "modules", "voting_module.R"))
source(file.path(app_dir, "modules", "leaderboard_module.R"))
source(file.path(app_dir, "modules", "user_stats_module.R"))
source(file.path(app_dir, "modules", "about_module.R"))
