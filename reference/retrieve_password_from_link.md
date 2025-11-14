# Retrieve a password using a retrieval token

Looks up the password corresponding to a retrieval link token and marks
the link as shown in the database.

## Usage

``` r
retrieve_password_from_link(token, conn)
```

## Arguments

- token:

  Character. Retrieval token from the URL path.

- conn:

  Database connection object.

## Value

Character password if token is valid, otherwise NULL.
