# Copilot Instructions

## Project Snapshot

- `ShinyImgVoteR` is an R package that ships a Shiny app from `inst/shiny-app`; `R/main_ui.R` plus `R/main_server.R` wire modules around an SQLite annotations DB and per-user TSV logs.
- Launch locally with `renv::restore()` followed by `devtools::load_all(".")` and `ShinyImgVoteR::run_voting_app()` (or `dev_scripts/run_shinyimgvoter.R`); hosted deployments use the same entrypoint (see `app.R`).

## Architecture & Flow

- `init_environment()` (R/init*env.R) prepares `app_env/` by copying templates from `inst/shiny-app/default_env`, normalising relative paths with `IMGVOTER_BASE_DIR`, and exporting `IMGVOTER*\*` env vars consumed throughout the app—always let this run before filesystem touches.
- `load_config()` (R/load_config.R) ingests `config/config.yaml`, merges env overrides, expands derived fields (`cfg$db_cols`, `cfg$vote2dbcolumn_map`, `cfg$observations2val_map`); pass the resulting `cfg` into every module.
- `makeVotingAppServer()` orchestrates authentication via `mod_login.R`/`shinyauthr`, tab triggers, logout cleanup, and registers modules; when extending functionality keep UI (`main_ui.R`) and server tab triggers in sync.
- Voting flow (`mod_voting.R`): reads the next coordinate from per-user TSVs, saves votes, and updates SQLite counts using `cfg$vote2dbcolumn_map`; `validate_cols()` guards SQL identifiers so new config columns must exist in the DB schema defined in `create_database()`.
- Dynamic tabs (Admin, etc.) are inserted at runtime—if you add tabs, update `make_tab_trigger()` and the navbar in `main_ui.R` so query-string syncing keeps working.

## Conventions

- Modules live in `R/mod_<name>.R` with paired `<name>UI()`/`<name>Server()` exports; UI functions accept `cfg` whenever styling or labels differ from defaults.
- Indent R code with 2 spaces; prefer `session$ns()` for dynamic IDs and keep module state in `session$userData` when persisting per-user context.
- Reuse helpers in `R/init_env_utils.R` (`safe_dir_create`, `copy_dir_from_app`, `ensure_gitignore`) instead of rolling bespoke filesystem logic—tests rely on their validation behaviour.

## Config, Data & Assets

- Runtime assets live in `app_env/` (config, images, server_data, user_data); defaults reside under `inst/shiny-app/default_env`. Tests mirror this structure in `tests/testthat/app_env/`—keep both copies updated when templates change.
- User progress persists in TSVs (`user_data/<institute>/<userid>`); columns must match `cfg$user_annotations_colnames` so `mod_voting.R` can restore prior choices and compute timing stats.
- Front-end behaviour (zoom, keyboard shortcuts) loads from `inst/shiny-app/www/js`; include new scripts via the `purrr::map` block in `votingUI()` to ensure singleton injection.

## Testing & Tooling

- Run `devtools::test()` (after `renv::restore()`) for the full suite; module tests use `testServer()` (`tests/testthat/test-*-module.R`) and helpers such as `tests/testthat/helper-db.R::create_mock_db()`.
- Coverage via `covr::package_coverage()` or `dev_scripts/coverage.R`; outputs land in `tests/coverage/`.
- When altering module signatures or config loading, update the fixtures in `tests/testthat/setup.R` and `tests/testthat/helper-*.R` so login, DB, and environment mocks stay aligned.

## Common Pitfalls

- Skipping `init_environment()` leaves relative paths unresolved and prevents `IMGVOTER_*` env vars from being set—most file IO and DB calls will fail.
- `load_config()` decorates observation labels with hotkey hints; hard-coding labels elsewhere breaks keyboard shortcut expectations.
- Schema tweaks go through `R/db_utils.R::create_database()`; adjust the SQLite template in `tests/testthat/app_env/db.sqlite` and regenerate user fixtures when you add or rename columns.
