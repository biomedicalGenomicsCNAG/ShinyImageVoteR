# Copilot Instructions

This file provides guidance for GitHub Copilot when working with the B1MG Variant Voting Shiny application.

## Project Overview

This is a sophisticated voting system designed for collaborative annotation of genetic mutations. It's packaged as an R package (`ShinyImgVoteR`) that contains a Shiny application.

## Project Structure

- `/R/`: R package source code
  - `mod_*.R`: Shiny modules for different functionalities (voting, leaderboard, login, user stats, about, FAQ, admin)
  - `main_ui.R`, `main_server.R`: Main Shiny app UI and server logic
  - `run_app.R`: Entry point to run the application
  - `db_utils.R`: Database operations utilities
  - `init_env.R`, `init_env_utils.R`: Environment initialization
  - `load_config.R`: Configuration loading
  - `voting_utils.R`, `logout_utils.R`, `admin_utils.R`: Utility functions
- `/inst/shiny-app/`: Shiny app resources bundled with the package
  - `/default_env/`: Default environment configuration, images, and user data templates
  - `/www/`: Static web resources (JavaScript, CSS)
- `/tests/testthat/`: Unit tests
- `/man/`: Package documentation (auto-generated)
- `app_env/`: External environment for development (config, user_data, images, server_data)

## Coding Conventions

- Use Shiny modules consistently: both UI and server in one file
  - UI function: `<module>UI` (e.g., `votingUI`)
  - Server function: `<module>Server` (e.g., `votingServer`)
- Module files named `mod_<module>.R` (e.g., `mod_voting.R`)
- Indent code with 2 spaces
- Use roxygen2 comments for function documentation
- Follow R package development best practices

## Architecture & Flow

- Use `testthat` for unit tests
- Use `testServer` for testing Shiny modules
- To run all tests: `devtools::test()`
- Ensure tests are placed in `tests/testthat/`
- To get test coverage: `covr::package_coverage()`
- Helper files in `tests/testthat/` start with `helper-` (e.g., `helper-db.R`)

## Build and Development

- Build the package: `make build` or `R CMD build .`
- Install the package: `make install` or `R CMD INSTALL ShinyImgVoteR_*.tar.gz`
- Run the app: `make run` or `R -e "ShinyImgVoteR::run_app()"`
- Check package: `make check` or `R CMD check ShinyImgVoteR_*.tar.gz`
- Generate documentation: `devtools::document()`
- Setup development environment: `make setup-dev`

## Configuration

- Configuration file: `app_env/config/config.yaml` (or specified via `IMGVOTER_CONFIG_FILE_PATH`)
- Environment variables:
  - `IMGVOTER_BASE_DIR`: Base directory for the application
  - `IMGVOTER_CONFIG_FILE_PATH`: Path to config file
  - `IMGVOTER_IMAGES_DIR`: Directory containing mutation images

## Key Workflows

1. **Development**: `make dev` - document, build, install, test
2. **CI/CD simulation**: `make ci` - deps, document, build, check, test, coverage
3. **Run application**: First `make setup-userdata`, then `make run`

## Database

- Uses SQLite for storing annotations and vote counts
- Database utilities in `R/db_utils.R`
- Database schema includes: coordinates, vote counts (yes/no/diff_var/not_confident), vartype, etc.

## Important Notes

- The app is designed as an R package for better testing and deployment
- External data (user_data, images, config) lives outside the package in `app_env/`
- Always use `get_app_dir()` to reference bundled resources in `inst/shiny-app/`
