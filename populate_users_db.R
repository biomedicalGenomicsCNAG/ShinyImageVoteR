#!/usr/bin/env Rscript

# Script to populate the SQLite database with users from institute2userids.yaml
# and automatically generated passwords

library(yaml)
library(DBI)
library(RSQLite)

# Function to generate a random password
generate_password <- function(length = 12) {
  chars <- c(letters, LETTERS, 0:9, "!@#$%^&*")
  paste(sample(chars, length, replace = TRUE), collapse = "")
}

# Read the institute2userids.yaml file
institute_file <- "/home/ivo/projects/bioinfo/cnag/repos/B1MG-variant-voting/config/institute2userids.yaml"
institute_data <- yaml::read_yaml(institute_file)

# Debug: print the structure
cat("Raw institute_data structure:\n")
str(institute_data)

# Extract all userids with their institutes
user_institute_map <- data.frame(userid = character(0), institute = character(0), stringsAsFactors = FALSE)

for (institute in names(institute_data)) {
  users <- institute_data[[institute]]
  cat("Institute:", institute, "\n")
  cat("Users structure:\n")
  str(users)
  
  # Handle different possible structures
  if (is.list(users)) {
    # If it's a list, extract the values
    clean_users <- unlist(users)
  } else if (is.character(users)) {
    # If it's a character vector
    clean_users <- users
  } else {
    # Convert to character
    clean_users <- as.character(users)
  }
  
  # Remove any leading/trailing whitespace and dashes
  clean_users <- trimws(gsub("^-", "", clean_users))
  cat("Clean users:", paste(clean_users, collapse = ", "), "\n")
  
  # Add to the mapping
  institute_users <- data.frame(
    userid = clean_users,
    institute = institute,
    stringsAsFactors = FALSE
  )
  user_institute_map <- rbind(user_institute_map, institute_users)
}

userids <- user_institute_map$userid
cat("Found users:", paste(userids, collapse = ", "), "\n")

# Connect to the database
db_file <- "/home/ivo/projects/bioinfo/cnag/repos/B1MG-variant-voting/db.sqlite"
con <- DBI::dbConnect(RSQLite::SQLite(), db_file)

# Check current users in the database
existing_users <- DBI::dbGetQuery(con, "SELECT userid FROM passwords")$userid
cat("Existing users in database:", paste(existing_users, collapse = ", "), "\n")

# Add new users (skip existing ones)
new_users <- setdiff(userids, existing_users)
cat("New users to add:", paste(new_users, collapse = ", "), "\n")

if (length(new_users) > 0) {
  # Get the institute information for new users
  new_user_data <- user_institute_map[user_institute_map$userid %in% new_users, ]
  
  # Prepare data for insertion
  user_data <- data.frame(
    userid = new_user_data$userid,
    institute = new_user_data$institute,
    password = sapply(new_user_data$userid, function(x) generate_password()),
    password_retrieval_link = NA_character_,
    link_clicked_timestamp = NA_character_,
    stringsAsFactors = FALSE
  )
  
  # Insert new users
  DBI::dbWriteTable(con, "passwords", user_data, append = TRUE)
  cat("Added", length(new_users), "new users to the database\n")
  
  # Display the newly added users and their passwords
  cat("\nNewly added users and their passwords:\n")
  for (i in 1:nrow(user_data)) {
    cat("User:", user_data$userid[i], "Institute:", user_data$institute[i], "Password:", user_data$password[i], "\n")
  }
} else {
  cat("No new users to add. All users already exist in the database.\n")
}

# Display all users in the database
all_users <- DBI::dbGetQuery(con, "SELECT userid, institute, password FROM passwords ORDER BY institute, userid")
cat("\nAll users in the database:\n")
print(all_users)

# Close the connection
DBI::dbDisconnect(con)

cat("\nDatabase population completed!\n")
