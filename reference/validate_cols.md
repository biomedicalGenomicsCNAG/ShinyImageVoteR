# Validate column names passed by config Ensures that the columns specified in the configuration are safe and exist in the database schema.

Validate column names passed by config Ensures that the columns
specified in the configuration are safe and exist in the database
schema.

## Usage

``` r
validate_cols(conn, table, cfg_db_cols)
```

## Arguments

- conn:

  Database connection object

- table:

  Name of the table to validate against

- cfg_db_cols:

  Character vector of column names from config

## Value

A character vector of validated column names
