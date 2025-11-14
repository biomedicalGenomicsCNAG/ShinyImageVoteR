# User Stats Server Module

This module provides user statistics functionality with automatic
refresh when navigating to the user stats tab.

## Usage

``` r
userStatsServer(id, cfg, login_trigger, db_pool, tab_trigger = NULL)
```

## Arguments

- id:

  Module namespace ID

- login_trigger:

  Reactive that triggers when user logs in

- db_pool:

  Database connection pool

- tab_trigger:

  Optional reactive that triggers when the user stats tab is selected
  This enables automatic refresh of stats when navigating to the page

## Value

Reactive containing user statistics data frame
