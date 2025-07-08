library(pool)
library(RSQLite)

source("config.R")

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

