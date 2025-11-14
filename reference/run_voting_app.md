# Run B1MG Variant Voting Shiny Application

This function launches the B1MG Variant Voting Shiny application.

## Usage

``` r
run_voting_app(
  host = "127.0.0.1",
  port = 8000,
  launch.browser = TRUE,
  config_file_path = file.path(get_app_dir(), "default_env", "config", "config.yaml"),
  ...
)
```

## Arguments

- host:

  Character. Host to run the application on. Default is "127.0.0.1"

- port:

  Integer. Port to run the application on. Default is NULL (random port)

- launch.browser:

  Logical. Should the browser be launched? Default is TRUE

- config_file_path:

  Character. Path to the configuration file. Default is the on in the
  app directory

## Value

Runs the Shiny application

## Examples

``` r
if (FALSE) { # \dontrun{
run_voting_app()
run_voting_app(config_file_path = "path/to/config.yaml")
} # }
```
