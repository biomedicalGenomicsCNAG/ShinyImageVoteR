# Copilot Instructions

## Coding Conventions

- Use Shiny modules consistently: both in one file UI (`<module>UI`) +
  server (`<module>Server`)
- Modules files named `mod_<module>.R`
- Indent code with 2 spaces

## Testing

- Use `testthat` for unit tests
- Use `testServer` for testing Shiny modules
- To run all tests, use
  [`devtools::test()`](https://devtools.r-lib.org/reference/test.html)
- Ensure tests are placed in `tests/testthat/`
- To get test coverage, use \`covr::package_coverage()
