# Colorize a DNA/RNA sequence using HTML span tags.

This function takes a nucleotide sequence and a named vector mapping
nucleotides to colors, and returns an HTML string where each nucleotide
is wrapped in a span tag with the corresponding color.

## Usage

``` r
color_seq(seq, nt2color_map)
```

## Arguments

- seq:

  A character string representing the nucleotide sequence.

- nt2color_map:

  A named character vector mapping nucleotides (e.g., "A", "T", "C",
  "G") to color values (e.g., "#FF0000").

## Value

A character string containing the HTML-formatted, colorized sequence.

## Examples

``` r
nt2color_map <- c(A = "#FF0000", T = "#00FF00", C = "#0000FF", G = "#FFFF00")
color_seq("ATCG", nt2color_map)
#> [1] "<span style=\"color:#FF0000\">A</span><span style=\"color:#00FF00\">T</span><span style=\"color:#0000FF\">C</span><span style=\"color:#FFFF00\">G</span>"
```
