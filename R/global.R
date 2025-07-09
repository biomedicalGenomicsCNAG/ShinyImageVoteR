library(pool)
library(RSQLite)

source("config.R")

source("modules/login_module.R")
source("modules/voting_module.R")
source("modules/leaderboard_module.R")
source("modules/user_stats_module.R")
source("modules/about_module.R")

# Initialize the SQLite database
if (!file.exists(cfg_sqlite_file)) {
  source("init_db.R")
}

db_pool <- dbPool(
  RSQLite::SQLite(),
  dbname = cfg_sqlite_file
)
onStop(function() {
  poolClose(db_pool)
})

