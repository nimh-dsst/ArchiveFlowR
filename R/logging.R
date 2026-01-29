af_log_levels <- c(
  debug = 10,
  info = 20,
  warn = 30,
  error = 40,
  none = 100
)

af_log_level <- function() {
  opt <- getOption("archiveflow.log.level")
  if (!is.null(opt)) {
    opt <- as.character(opt)
    if (nzchar(opt)) {
      return(tolower(opt))
    }
  }

  env <- Sys.getenv("ARCHIVEFLOW_LOG_LEVEL", "")
  if (nzchar(env)) {
    return(tolower(env))
  }

  "info"
}

af_log_level_value <- function(level) {
  level <- tolower(as.character(level))
  if (!level %in% names(af_log_levels)) {
    level <- "info"
  }
  af_log_levels[[level]]
}

af_log_enabled <- function(level) {
  af_log_level_value(level) >= af_log_level_value(af_log_level())
}

af_log <- function(level, ..., .sep = "") {
  if (!af_log_enabled(level)) {
    return(invisible(FALSE))
  }

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  label <- toupper(as.character(level))
  msg <- paste(..., sep = .sep)
  message(sprintf("[%s] [%s] %s", timestamp, label, msg))
  invisible(TRUE)
}

af_log_preview <- function(value, max = 400) {
  if (is.null(value)) {
    return("")
  }
  if (max <= 0) {
    return("")
  }
  text <- paste(as.character(value), collapse = "")
  if (!nzchar(text)) {
    return(text)
  }
  if (nchar(text) <= max) {
    return(text)
  }
  paste0(substr(text, 1, max), "...[truncated]")
}

af_log_set_level <- function(level) {
  options(archiveflow.log.level = tolower(as.character(level)))
  invisible(level)
}

af_log_debug <- function(...) af_log("debug", ...)
af_log_info <- function(...) af_log("info", ...)
af_log_warn <- function(...) af_log("warn", ...)
af_log_error <- function(...) af_log("error", ...)
