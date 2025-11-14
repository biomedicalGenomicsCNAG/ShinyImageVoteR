# Leaderboard Server Module

This module provides leaderboard functionality with automatic refresh
when navigating to the leaderboard tab.

## Usage

``` r
leaderboardServer(id, cfg, login_trigger, tab_trigger = NULL)
```

## Arguments

- id:

  Module namespace ID

- login_trigger:

  Reactive that triggers when user logs in

- tab_trigger:

  Optional reactive that triggers when the leaderboard tab is selected
  This enables automatic refresh of counts when navigating to the page

## Value

Reactive containing leaderboard data frame
