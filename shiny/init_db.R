library(DBI)
library(RSQLite)

# Path to the text file with screenshot info
text_file <- "./screenshots/uro003_paths_mock.txt"
# Path to the sqlite database
sqlite_file <- "./screenshots/annotations.sqlite"

# Create database only if it doesn't exist
if (!file.exists(sqlite_file)) {
  df <- read.table(text_file, sep="\t", header = FALSE, stringsAsFactors = FALSE)
  colnames(df) <- c("coordinates", "REF", "ALT", "variant", "path")
  df$vote_count <- 0L

  con <- dbConnect(SQLite(), sqlite_file)
  dbWriteTable(con, "annotations", df, overwrite = TRUE)
  dbDisconnect(con)
}
