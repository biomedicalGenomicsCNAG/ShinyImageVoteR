# Load voting app configuration

Returns a list of configuration values, optionally overridden by
environment variables or external files.

## Usage

``` r
load_config(config_file_path)
```

## Arguments

- config_file_path:

  Character. Path to the configuration file. Default is the one in the
  app directory

## Value

A named list of configuration values (e.g., `cfg_sqlite_file`,
`cfg_radio_options2val_map`, etc.)
