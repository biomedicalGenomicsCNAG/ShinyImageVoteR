# Initialize environment for the application

Sets up the app environment directory and the database.

## Usage

``` r
init_environment(config_file_path)
```

## Arguments

- config_file_path:

  Character. Path to the configuration file. Default is
  app_env/config/config.yaml in the current working directory.

## Value

List with paths to user_data directory, database file, and config file
