#' Find a .env file by walking up the directory tree
#'
#' `r lifecycle::badge("stable")`
#' @param start_dir Directory to start searching from (default: getwd())
#' @param filename Name of the env file (default: ".env")
#' @return Path to the first matching file or NULL if none found
#' @export
find_env_file <- function(start_dir = getwd(), filename = ".env") {
  dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  repeat {
    candidate <- file.path(dir, filename)
    if (file.exists(candidate)) {
      return(candidate)
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
  NULL
}

#' Load environment variables from a .env file if present
#'
#' `r lifecycle::badge("stable")`
#' @param path Optional path to a specific .env file
#' @return TRUE if a file was loaded, FALSE otherwise
#' @export
load_env_file <- function(path = NULL) {
  if (isTRUE(getOption("archiveflow.env_loaded"))) {
    return(invisible(FALSE))
  }

  if (is.null(path)) {
    path <- find_env_file()
  }
  if (is.null(path) || !file.exists(path)) {
    return(invisible(FALSE))
  }

  lines <- readLines(path, warn = FALSE)
  env <- list()
  for (line in lines) {
    line <- trimws(line)
    if (line == "" || startsWith(line, "#")) next
    line <- sub("^export\\s+", "", line)
    if (!grepl("=", line, fixed = TRUE)) next

    key <- trimws(sub("=.*$", "", line))
    value <- trimws(sub("^[^=]*=", "", line))
    value <- sub('^"(.*)"$', "\\1", value)
    value <- sub("^'(.*)'$", "\\1", value)

    if (nzchar(key) && Sys.getenv(key, "") == "") {
      env[[key]] <- value
    }
  }

  if (length(env) > 0) {
    do.call(Sys.setenv, env)
  }
  options(archiveflow.env_loaded = TRUE)
  invisible(TRUE)
}

#' Get application configuration from environment variables
#'
#' `r lifecycle::badge("stable")`
#' Reads configuration from environment variables, with sensible defaults.
#' Environment variables should be set in a .env file in the project root.
#'
#' @return A list containing all configuration values
#' @export
get_config <- function() {
  load_env_file()

  env_or <- function(primary, fallback = NULL, default = "") {
    value <- Sys.getenv(primary, "")
    if (nzchar(value)) {
      return(value)
    }
    if (!is.null(fallback)) {
      value <- Sys.getenv(fallback, "")
      if (nzchar(value)) {
        return(value)
      }
    }
    default
  }

  list(
    labarchives_url = env_or("LA_API_URL", "api_url", "https://api.labarchives-gov.com/api"),
    labarchives_akid = env_or("LA_ACCESS_KEY_ID", "access_key_id", ""),
    labarchives_password = env_or("LA_ACCESS_PASSWORD", "access_password", ""),
    labarchives_ssl_cer = env_or("LA_SSL_CER", "ssl_cer", ""),
    app_host = {
      raw_host <- trimws(Sys.getenv("app_host", ""))
      if (!nzchar(raw_host)) {
        raw_host <- ""
      }
      raw_host
    }
  )
}

#' Resolve LabArchives credentials from config
#'
#' `r lifecycle::badge("stable")`
#' @param input_akid Unused (kept for backward compatibility).
#' @param input_password Unused (kept for backward compatibility).
#' @param config Optional configuration list from get_config().
#' @return Named list with `akid` and `password`.
#' @export
resolve_labarchives_creds <- function(input_akid = NULL, input_password = NULL, config = NULL) {
  if (is.null(config)) {
    config <- get_config()
  }

  list(
    akid = config$labarchives_akid,
    password = config$labarchives_password
  )
}

#' Resolve LabArchives redirect URI for auth flow
#'
#' `r lifecycle::badge("stable")`
#' Uses app_host from the environment. Returns NULL when unset.
#'
#' @param config Optional configuration list from get_config().
#' @return Redirect URI string.
#' @export
resolve_labarchives_redirect <- function(config = NULL) {
  if (is.null(config)) {
    config <- get_config()
  }

  app_host_env <- trimws(Sys.getenv("app_host", ""))
  if (nzchar(app_host_env)) {
    return(app_host_env)
  }

  if (!is.null(config$app_host) && nzchar(config$app_host)) {
    return(config$app_host)
  }

  NULL
}

#' Check if LabArchives is configured
#'
#' `r lifecycle::badge("stable")`
#' Tests whether the required LabArchives configuration variables are set.
#'
#' @param config Configuration list from get_config(). If NULL, fetches fresh
#' config.
#' @return TRUE if both AKID and password are configured, FALSE otherwise
#'
#' @export
is_labarchives_configured <- function(config = NULL) {
  if (is.null(config)) {
    config <- get_config()
  }
  nzchar(config$labarchives_akid) && nzchar(config$labarchives_password)
}
