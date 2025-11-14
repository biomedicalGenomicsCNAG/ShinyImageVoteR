# Admin module server

Shows password retrieval tokens for users who have not accessed their
retrieval link and allows admins to add new users.

## Usage

``` r
adminServer(id, cfg, login_trigger, db_pool, tab_trigger = NULL)
```

## Arguments

- id:

  Module namespace

- cfg:

  App configuration

- login_trigger:

  Reactive containing login data

- db_pool:

  Database connection pool

- tab_trigger:

  Optional reactive triggered when admin tab is selected
