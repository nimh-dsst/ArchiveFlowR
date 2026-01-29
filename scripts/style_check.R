if (!requireNamespace("styler", quietly = TRUE)) {
  stop("styler is required. Run 'pixi install' to add dependencies.")
}

style_paths <- c("R", "tests")
style_files <- unlist(
  lapply(style_paths, function(path) {
    if (!dir.exists(path)) {
      return(character())
    }
    list.files(
      path,
      pattern = "\\.(R|Rmd|Rnw|qmd)$",
      recursive = TRUE,
      full.names = TRUE
    )
  }),
  use.names = FALSE
)

if (length(style_files) == 0) {
  quit(status = 0)
}

styler::style_file(style_files, dry = "fail")
