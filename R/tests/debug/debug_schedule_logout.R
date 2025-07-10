#!/usr/bin/env Rscript

source('../../config.R')
source('../../server_utils.R')
library(later)

# Test the functions directly
cat('Testing functions directly...\n')

# Try to schedule a simple task
test_executed <- FALSE
test_callback <- function() { 
  cat('Callback executed!\n')
  test_executed <<- TRUE 
}

cat('Before scheduling:\n')
schedule_logout_update('test_session', test_callback, delay = 0.5)
cat(
  'After scheduling, session exists:', 
  exists('test_session', envir = pending_logout_tasks), '\n'
)

# Test cancellation
cancel_pending_logout('test_session')
cat(
  'After cancellation, session exists:', 
  exists('test_session', envir = pending_logout_tasks), '\n'
)

cat('Test completed successfully\n')