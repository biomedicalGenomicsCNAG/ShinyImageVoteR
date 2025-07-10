source('../../config.R')
source('../../server_utils.R')
library(later)

# Test the functions directly
cat('Testing functions directly...\n')
cat('pending_logout_tasks exists:', exists('pending_logout_tasks'), '\n')
cat('schedule_logout_update exists:', exists('schedule_logout_update'), '\n')

# Try to schedule a simple task
test_executed <- FALSE
test_callback <- function() { 
  cat('Callback executed!\n')
  test_executed <<- TRUE 
}

cat('Before scheduling:\n')
cat('Environment contents:', ls(envir = pending_logout_tasks), '\n')

schedule_logout_update('test_session', test_callback, delay = 0.1)

cat('After scheduling:\n')
cat('Environment contents:', ls(envir = pending_logout_tasks), '\n')
cat('Session exists:', exists('test_session', envir = pending_logout_tasks), '\n')

Sys.sleep(0.2)
cat('Final callback status:', test_executed, '\n')