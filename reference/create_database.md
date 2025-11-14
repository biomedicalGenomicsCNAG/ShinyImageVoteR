# Initialize SQLite database

Initialize SQLite database

## Usage

``` r
create_database(db_path, to_be_voted_images_file, grouped_credentials)
```

## Arguments

- db_path:

  Character. Path to the SQLite database file to create

- to_be_voted_images_file:

  Character. Path to the file containing image annotations

- grouped_credentials:

  List. Parsed YAML list of grouped credentials

## Value

Character path to the database file
