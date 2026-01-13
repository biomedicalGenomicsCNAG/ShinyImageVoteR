# ShinyImgVoteR

Is an open-source R Shiny image voting application initially developed for collaborative reviewing of
mutation calls from sequencing data in the course of the [Beyond 1 Million Genomes (B1MG) project](https://b1mg-project.eu). Refer to [ShinyImgVoteR's role in the B1MG project](doc/01-introduction.html) for more context.

## Overview

The application enables users to vote on any set of images with features for tracking user behavior 
(e.g. average time before casting a vote), handling vote changes by allowing users to update their previous votes, and supporting keyboard shortcuts for efficient voting.

Users get presented a randomly picked image, as for instance an IGV (Integrative Genomics Viewer) screenshot displaying a genetic mutation, and can express their opinion on the shown mutation using predefined categories, confirming or rejecting its validity, proposing that there is a different mutation at the same location.





such as "True Positive", "False Positive", or "Uncertain". Votes are stored in a TSV file per user, and an SQLite database maintains aggregated vote counts for each mutation.

FLOW:

- User logs in → triggers mutation loading
- Mutation image and data displayed
- User makes voting choices → stored in TSV file
- Database updated with vote counts
- Next mutation loaded automatically
- Process repeats until all mutations voted on

<!-- [![](docs/ui.gif)](docs/ui.gif) -->

## Development Prerequisites

- R (developed with v4.5.0)

## Quickstart

1. Start the Shiny application:

```bash
R -e "renv::restore()"
R -e "ShinyImgVoteR::run_app()"
```

2. Navigate to http://localhost:8000

### AUTHOR

Written by Ivo Christopher Leist, PhD Candidate at CNAG [https://www.cnag.eu](https://www.cnag.eu).

### COPYRIGHT AND LICENSE

Copyright (C) 2025, Ivo Christopher Leist - CNAG.

GPLv3 - GNU General Public License v3.0
