# Voting module server logic

Handles the server-side logic for the mutation voting workflow. This
includes:

- Reactively loading mutation images and metadata

- Capturing user input (agreement, observation, comment)

- Writing votes to a tsv file and session data to a database

- Advancing to the next voting item based on user interaction or trigger
  source

## Usage

``` r
votingServer(
  id,
  cfg,
  login_trigger,
  db_pool,
  get_mutation_trigger_source,
  tab_trigger = NULL
)
```

## Arguments

- id:

  A string identifier for the module namespace.

- cfg:

  App configuration

- login_trigger:

  A reactive expression that indicates when a user has logged in.

- db_pool:

  A database pool object (e.g. SQLite or PostgreSQL) for writing
  annotations.

- get_mutation_trigger_source:

  A reactive expression that signals a new mutation should be loaded.

- tab_trigger:

  Optional reactive that triggers when the voting tab is selected.

## Value

None. Side effect only: registers reactive observers and UI updates.

## Details

The module is triggered when the `login_trigger` reactive becomes active
and optionally by `get_mutation_trigger_source()` to load new voting
tasks.

Annotations are saved to the database connection provided in `db_pool`.
