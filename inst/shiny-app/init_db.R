# This script initializes the SQLite database for the Shiny app.

#load necessary libraries
library(DBI)
library(RSQLite)

# load configuration (variables have a "cfg_" prefix)
source("config.R")

# Create database
df <- read.table(
  cfg_to_be_voted_images_file, 
  sep="\t", 
  header = FALSE, 
  stringsAsFactors = FALSE
)

colnames(df) <- cfg_db_general_cols
df[cfg_vote_counts_cols] <- lapply(cfg_vote_counts_cols, function(x) 0L)

# point the path to symlinked images directory
df$path <- gsub("/vol/b1mg/", "images/", df$path)

con <- dbConnect(SQLite(), cfg_sqlite_file)
dbWriteTable(con, "annotations", df, overwrite = TRUE)

dbExecute(con, "
  CREATE TRIGGER update_vote_total_update
  AFTER UPDATE ON annotations
  FOR EACH ROW
  BEGIN
    UPDATE annotations
    SET vote_count_total = 
        vote_count_correct +
        vote_count_no_variant +
        vote_count_different_variant +
        vote_count_not_sure
    WHERE rowid = NEW.rowid;
  END;
")

# create sessionids only if missing
if (!"sessionids" %in% dbListTables(con)) {
  print("Creating sessionids table - HERE")
  dbCreateTable(con,
    "sessionids",
    c(
      user        = "TEXT",
      sessionid   = "TEXT",
      login_time  = "TEXT",
      logout_time = "TEXT"
    )
  )
}

# show the created tables
print(dbListTables(con))

dbDisconnect(con)
