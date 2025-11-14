# This function checks if a .gitignore file exists in the specified directory. If it does not exist, it creates one. It then ensures that the specified patterns are present in the .gitignore file, adding them if they are missing.

This function checks if a .gitignore file exists in the specified
directory. If it does not exist, it creates one. It then ensures that
the specified patterns are present in the .gitignore file, adding them
if they are missing.

## Usage

``` r
ensure_gitignore(directory, patterns)
```

## Arguments

- patterns:

  Character vector. Patterns to ensure in the .gitignore file.

- dir:

  Character. Directory path where the .gitignore file should be
  checked/created.

## Value

Character path to the .gitignore file
