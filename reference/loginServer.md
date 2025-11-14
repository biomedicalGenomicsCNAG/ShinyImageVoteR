# Login module server logic

Handles user authentication and session tracking using the `shinyauthr`
package. This module supports login via a database-backed user table and
emits reactive values for downstream modules to consume.

## Usage

``` r
loginServer(id, cfg, db_conn = NULL, log_out = reactive(NULL))
```

## Arguments

- id:

  A string identifier for the module namespace.

- db_conn:

  A database pool connection (e.g. SQLite or PostgreSQL) used to track
  sessions.

- log_out:

  A reactive trigger (default: `reactive(NULL)`) to perform logout
  actions.

## Value

A list containing:

- login_data:

  A `reactiveVal` holding login metadata (e.g. user ID, voting
  institute, session ID)

- credentials:

  A `reactive` object with user authentication status

- update_logout_time:

  A function to record logout time for a session ID

## Details

It also supports optional logout triggering and updates the session
tracking database.
