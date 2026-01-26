# Admin module server

Shows password retrieval tokens for users, allows admins to add new
users, enables downloading user annotations, and provides functionality
to reset user annotations.

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
