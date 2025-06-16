
# Shiny App
	
## Quickstart

```bash
R -e "renv::restore()"
Rscript run.R
```

# Note for gcloud users
RAM has to be > 256MB


# TODO
- [ ] Store the uro003_paths.txt file in a sqlite database*

*We want to track how often each screenshot has been voted
so we can skip the screenshot for an individual user if 
at least three users have voted for it already.

