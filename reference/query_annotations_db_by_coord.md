# Query annotations table by coordinates and optionally REF/ALT This function queries the annotations table for a given set of coordinates, returning only the specified columns. Optionally filters by REF and ALT to handle cases where coordinates alone are not unique.

Query annotations table by coordinates and optionally REF/ALT This
function queries the annotations table for a given set of coordinates,
returning only the specified columns. Optionally filters by REF and ALT
to handle cases where coordinates alone are not unique.

## Usage

``` r
query_annotations_db_by_coord(
  conn,
  coord,
  cols,
  ref = NULL,
  alt = NULL,
  query_keys = NULL
)
```

## Arguments

- conn:

  Database connection object

- coord:

  Character. The coordinates to query (exact match)

- cols:

  Character vector. The columns to retrieve

- ref:

  Character. Optional REF allele to query (exact match)

- alt:

  Character. Optional ALT allele to query (exact match)

- query_keys:

  Character vector. Optional query keys to use for filtering. If not
  provided, defaults to c("coordinates", "REF", "ALT") if ref and alt
  are provided, otherwise just "coordinates".

## Value

A data frame with the query results
