# 04. Test Coverage

## Test Coverage

The vignette demonstrates how to generate a coverage report for the
package using the **covr** package. To run the coverage analysis
locally, execute:

``` r
library(covr)
coverage <- package_coverage()
report(coverage, browse = FALSE, file = "coverage.html")
```

The generated `coverage.html` file provides a detailed view of which
functions are exercised by the test suite located in `tests/testthat/`.

You can also view a summary in the console:

``` r
print(coverage)
```
