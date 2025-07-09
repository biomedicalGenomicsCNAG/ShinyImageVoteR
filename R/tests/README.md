# Testing Suite for B1MG Variant Voting Application

This directory contains comprehensive test cases for the B1MG Variant Voting application.

## Test Structure

The test suite is organized into several files, each focusing on different aspects of the application:

### Test Files

1. **`test-config.R`** - Configuration validation tests
   - Tests that all configuration values are properly loaded
   - Validates institute IDs, credentials, and database column mappings
   - Ensures vote mapping and UI configurations are correct

2. **`test-login-module.R`** - Login module functionality tests
   - Tests login UI rendering
   - Database session management (insert, update, cleanup)
   - Session filtering and validation
   - Logout time updates

3. **`test-server-functions.R`** - Server-side functionality tests
   - User directory creation and management
   - User info and annotations file creation
   - Randomization seed generation and consistency
   - Logout scheduling and task management
   - External shutdown mechanism

4. **`test-database.R`** - Database operations tests
   - Database connection and query functionality
   - Vote counting and updates
   - Schema validation against configuration
   - Connection pool management

5. **`test-ui.R`** - User interface tests
   - Main UI structure validation
   - Conditional panel configuration
   - Navigation structure
   - Module UI namespacing
   - Integration tests (optional, requires `shinytest2`)

6. **`test-utils.R`** - Utility function tests
   - JSON and TSV file operations
   - Directory utilities and path construction
   - Hash and seed generation
   - Time utilities and string manipulation
   - Randomization utilities

### Support Files

- **`setup.R`** - Test environment setup and helper functions
- **`testthat.R`** - Main test configuration file

## Running Tests

### Prerequisites

Make sure you have the required packages installed:

```r
install.packages(c(
  "testthat", 
  "shinytest2",  # Optional, for integration tests
  "covr"         # Optional, for coverage reports
))
```

### Running All Tests

You can run tests in several ways:

#### Using R directly:
```r
library(testthat)
test_dir("tests/testthat")
```

#### Using the test runner script:
```bash
Rscript run_tests.R
```

#### Using the Makefile:
```bash
# Run all tests
make -f Makefile.test test

# Run specific test suites
make -f Makefile.test test-config
make -f Makefile.test test-login
make -f Makefile.test test-user-stats
make -f Makefile.test test-database
# etc.
```

### Running Individual Test Files

```r
# Test configuration
test_file("tests/testthat/test-config.R")

# Test login module
test_file("tests/testthat/test-login-module.R")

# Test user stats module  
test_file("tests/testthat/test-user-stats-module.R")

# Test database functionality
test_file("tests/testthat/test-database.R")
```

## Test Coverage

The test suite covers:

✅ **Configuration Management**
- All configuration values loading correctly
- Database column mappings
- Institute and user configurations
- Vote option mappings

✅ **Authentication & Session Management**
- User login and logout processes
- Session ID generation and tracking
- Database session storage and cleanup
- Session expiry handling

✅ **User Interface & Navigation**
- Tab-based navigation system
- Automatic refresh on tab selection
- Conditional panel display
- Module UI integration and namespacing

✅ **User Statistics**
- Statistics calculation and aggregation
- Automatic refresh when navigating to stats page
- Session-based data tracking
- Vote timing and frequency analysis

✅ **Database Operations**
- Connection management and pooling
- CRUD operations for annotations and sessions
- Vote counting and aggregation
- Schema validation

✅ **File Operations**
- User info JSON file creation and reading
- Annotations TSV file management
- Directory structure creation
- File path utilities

✅ **Server Logic**
- Reactive value management
- Observer functions
- Module integration
- Background task scheduling

✅ **UI Components**
- Main UI structure
- Conditional panels
- Module UI integration
- Navigation elements

✅ **Utility Functions**
- Hash generation and seed creation
- Time-based operations
- String manipulation
- Randomization utilities

## Test Environment

The tests use:
- **Temporary databases** for database tests (SQLite in-memory or temp files)
- **Temporary directories** for file operation tests
- **Mock data** for consistent test results
- **Helper functions** to set up and clean up test environments

## Notes for Developers

### Adding New Tests

When adding new functionality to the application, please:

1. Create corresponding test cases in the appropriate test file
2. Use the helper functions in `setup.R` for consistent test environments
3. Clean up any resources (databases, files) created during tests
4. Follow the existing naming conventions and test structure

### Test Data

All test data is generated programmatically or uses temporary resources. No real user data or production databases are used in tests.

### Continuous Integration

These tests are designed to run in automated CI/CD environments. They don't require interactive user input or external services.

## Troubleshooting

### Common Issues

1. **Package not found errors**: Install missing packages using `install.packages()`
2. **Permission errors**: Ensure write permissions to temp directories
3. **Database connection errors**: Check that RSQLite is properly installed
4. **Timeout errors**: Increase delay values in async tests if needed

### Debugging Tests

To debug failing tests:

```r
# Run with detailed output
options(testthat.progress.verbose = TRUE)
test_file("tests/testthat/test-name.R")

# Run a specific test
test_that("specific test name", {
  # test code here
})
```
