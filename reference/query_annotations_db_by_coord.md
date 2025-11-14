# Query annotations table by coordinates This function queries the annotations table for a given set of coordinates, returning only the specified columns.

Query annotations table by coordinates This function queries the
annotations table for a given set of coordinates, returning only the
specified columns.

## Usage

``` r
query_annotations_db_by_coord(conn, coord, cols)
```

## Arguments

- conn:

  Database connection object

- coord:

  Character. The coordinates to query (exact match)

- cols:

  Character vector. The columns to retrieve

## Value

A data frame with the query results
