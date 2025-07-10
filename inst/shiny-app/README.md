# Shiny App

## Quickstart

```bash
R -e "renv::restore()"
R -e "B1MGVariantVoting::run_app()"
```

# Note for gcloud users

RAM has to be > 256MB

# FAQ

## Why there is no logic to filter out screenshots that have been voted sufficiently enough already?

Gabriela:
we actually don’t need any filtering because everyone will vote everything.
This is kind of the actual purpose of the expert test and then,
depending on how the experts vote, we can add the filtering for the second voting round
