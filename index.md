# Shiny IMGVOTER (B1MG Voting App)

Sophisticated voting system designed for collaborative annotation of
genetic mutations, with features for tracking user behavior, handling
vote changes, and maintaining data integrity across multiple users.

Voting application that allows users to vote on different B1MG
mutations. Users get presented a randomly picked image of a B1MG
mutation and can vote for it.

FLOW:

- User logs in → triggers mutation loading
- Mutation image and data displayed
- User makes voting choices → stored in TSV file
- Database updated with vote counts
- Next mutation loaded automatically
- Process repeats until all mutations voted on

## Development Prerequisites

- R (developed with v4.5.0)

## Quickstart

1.  Start the Shiny application:

``` bash
R -e "renv::restore()"
R -e "ShinyImgVoteR::run_app()"
```

2.  Navigate to <http://localhost:8000>

### AUTHOR

Written by Ivo Christopher Leist, PhD student at CNAG
<https://www.cnag.eu>.

### COPYRIGHT AND LICENSE

Copyright (C) 2025, Ivo Christopher Leist - CNAG.

GPLv3 - GNU General Public License v3.0
