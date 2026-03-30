# Reset user annotation file and update database vote counts

Resets a user's annotation file by keeping the header row and the first
three columns (coordinates, REF, ALT) but clearing all other data
columns. Also updates the database by decrementing vote counts for all
votes that the user had cast. Additionally, resets the
vote_input_methods counts in the user's info.json file to 0. This allows
a user to start voting from scratch while preserving the randomized
order of variants.

## Usage

``` r
reset_user_annotations(
  annotation_file_path,
  user_annotations_colnames,
  db_pool,
  cfg
)
```

## Arguments

- annotation_file_path:

  Character. Full path to the user's annotation TSV file

- user_annotations_colnames:

  Character vector. Column names for the annotation file

- db_pool:

  Database connection pool

- cfg:

  App configuration containing radio_options db_column mappings

## Value

Logical. TRUE if reset was successful, FALSE otherwise
