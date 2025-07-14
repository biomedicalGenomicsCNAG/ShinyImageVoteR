#' Colorize a DNA/RNA sequence using HTML span tags.
#'
#' This function takes a nucleotide sequence and a named vector mapping nucleotides to colors,
#' and returns an HTML string where each nucleotide is wrapped in a span tag with the corresponding color.
#' 
#' @keywords internal
#' 
#' @param seq A character string representing the nucleotide sequence.
#' @param nt2color_map A named character vector mapping nucleotides (e.g., "A", "T", "C", "G") to color values (e.g., "#FF0000").
#'
#' @return A character string containing the HTML-formatted, colorized sequence.
#'
#' @examples
#' nt2color_map <- c(A = "#FF0000", T = "#00FF00", C = "#0000FF", G = "#FFFF00")
#' color_seq("ATCG", nt2color_map)
#'
#' @export
color_seq <- function(seq, nt2color_map) {
  seq %>%
    strsplit(split = "") %>%
    unlist() %>%
    sapply(function(x) sprintf('<span style="color:%s">%s</span>', nt2color_map[x], x)) %>%
    paste(collapse = "")
}