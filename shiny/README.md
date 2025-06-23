# Shiny App

## Quickstart

```bash
R -e "renv::restore()"
Rscript run.R
```

# Note for gcloud users

RAM has to be > 256MB

# TODO

- [x] Store the uro003_paths.txt file in a sqlite database\*

\*We want to track how often each screenshot has been voted
so we can skip the screenshot for an individual user if
at least three users have voted for it already.

# FAQ

## Why there is no logic to filter out screenshots that have been voted sufficiently enough already?

Gabriela:
we actually don’t need any filtering because everyone will vote everything.
This is kind of the actual purpose of the expert test and then,
depending on how the experts vote, we can add the filtering for the second voting round
