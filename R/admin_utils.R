# coalescing operator: return `a` if it exists and is non-empty,
# otherwise fall back to `b`.
`%||%` <- function(a, b) {
  # If `a` is NULL, there is nothing to return
  if (is.null(a)) {
    return(b)
  }

  # If `a` is a character but empty ("") or all whitespace, also use `b`
  if (is.character(a) && !nzchar(a)) {
    return(b)
  }

  # Otherwise keep the original value
  a
}


#' Build base URL from session data, accounting for reverse proxy subpaths
#'
#' @param session Shiny session object
#' @return Complete base URL including protocol, host, port, and pathname
#' @export
build_base_url <- function(session) {
  # 1) Protocol from the browser, not guessed from port
  proto_raw <- session$clientData$url_protocol %||% "https:"
  proto <- sub(":$", "", tolower(proto_raw)) # "http:" -> "http"

  # 2) Hostname
  host <- session$clientData$url_hostname %||% "localhost"

  # 3) Port: include only if present and non-default for the protocol
  port_val <- session$clientData$url_port
  port_part <- ""
  if (!is.null(port_val) && nzchar(as.character(port_val))) {
    port_num <- suppressWarnings(as.integer(port_val))
    is_default <- (proto == "http" && identical(port_num, 80L)) ||
      (proto == "https" && identical(port_num, 443L))
    if (!is_default) port_part <- paste0(":", port_val)
  }

  # 4) Pathname: keep subpath, drop query, normalize trailing slash
  pathname <- session$clientData$url_pathname %||% "/"
  pathname <- sub("\\?.*$", "", pathname)
  if (!nzchar(pathname)) pathname <- "/"
  if (!grepl("/$", pathname)) pathname <- paste0(pathname, "/")

  paste0(proto, "://", host, port_part, pathname)
}
