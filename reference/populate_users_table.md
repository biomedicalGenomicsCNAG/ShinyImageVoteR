# Populate the users table with data from grouped credentials (per-institute lists)

Expected YAML shape: \<institute_name\>:

- userid: password: \|NULL admin: true\|false \# optional

## Usage

``` r
populate_users_table(conn, grouped_credentials)
```

## Arguments

- conn:

  Database connection object

- grouped_credentials:

  list; parsed YAML

## Details

Columns written: userid, institute, password, admin,
password_retrieval_link, link_clicked_timestamp
