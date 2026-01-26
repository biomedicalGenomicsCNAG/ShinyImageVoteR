# Update the annotations table with new entries from the file

This function checks for new entries in the to_be_voted_images_file and
adds only the ones that don't already exist in the database.

## Usage

``` r
update_annotations_table(conn, to_be_voted_images_file)
```

## Arguments

- conn:

  Database connection object

- to_be_voted_images_file:

  Character. Path to the file containing image annotations

## Value

List with counts: added, updated, removed
