if (!requireNamespace("styler", quietly = TRUE)) {
  stop("styler is required. Run 'pixi install' to add dependencies.")
}
if (!requireNamespace("lintr", quietly = TRUE)) {
  stop("lintr is required. Run 'pixi install' to add dependencies.")
}
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
}

args <- commandArgs(trailingOnly = TRUE)

staged_files <- if (length(args) > 0) {
  args
} else {
  system("git diff --cached --name-only --diff-filter=ACM", intern = TRUE)
}

if (length(staged_files) == 0) {
  quit(status = 0)
}

r_file_pattern <- "\\.(R|Rmd|Rnw|qmd)$"
r_files <- staged_files[grepl(r_file_pattern, staged_files)]

if (length(r_files) == 0) {
  quit(status = 0)
}

existing_r_files <- r_files[file.exists(r_files)]
if (length(existing_r_files) == 0) {
  quit(status = 0)
}

unstaged <- system2("git", c("diff", "--name-only", "--", existing_r_files), stdout = TRUE)
if (length(unstaged) > 0) {
  message("Unstaged changes detected in staged R files. Stage or stash them before committing:")
  writeLines(unstaged)
  quit(status = 1)
}

styler::style_file(existing_r_files)

styled_changes <- system2("git", c("diff", "--name-only", "--", existing_r_files), stdout = TRUE)
if (length(styled_changes) > 0) {
  message("Styler reformatted staged files. Review and re-stage these files:")
  writeLines(styled_changes)
  quit(status = 1)
}

lint_results <- unlist(
  lapply(existing_r_files, function(path) lintr::lint(filename = path)),
  recursive = FALSE
)

if (length(lint_results) > 0) {
  print(lint_results)
  quit(status = 1)
}
