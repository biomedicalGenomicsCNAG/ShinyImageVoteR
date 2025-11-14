# Create a Directory Safely

Validates that the target directory name is a single “word” (letters,
digits, and/or underscores only) before attempting to create it.
Optionally handles nested creation, warnings, and permission bits.

## Usage

``` r
safe_dir_create(
  path,
  pattern = "^[A-Za-z0-9_]+$",
  showWarnings = TRUE,
  recursive = FALSE
)
```

## Arguments

- path:

  Character. The name (or path) of the directory to create. Only the
  final component (basename) is validated.

- pattern:

  Character. A regular expression that the directory name must match.
  Default is `"^[A-Za-z0-9_]+$"`, i.e. one or more letters, digits, or
  underscores.

- showWarnings:

  Logical. If `TRUE`, warns when the directory already exists or cannot
  be created. Default is `TRUE`.

- recursive:

  Logical. If `TRUE`, creates any missing parent directories (like
  `mkdir -p`). Default is `FALSE`.

- mode:

  Character or numeric. Directory permissions in octal (e.g. `"0777"`).
  Default is `"0777"`.

## Value

Invisibly returns `TRUE` if the directory was successfully created,
`FALSE` otherwise. If the directory already exists, returns `FALSE`
(with a message, unless `showWarnings = FALSE`).

## Examples

``` r
# Successful creation
safe_dir_create("data_folder")
#> Error in safe_dir_create("data_folder"): could not find function "safe_dir_create"

# Fails validation (contains spaces)
try(safe_dir_create("my data"))
#> Error in safe_dir_create("my data") : 
#>   could not find function "safe_dir_create"
```
