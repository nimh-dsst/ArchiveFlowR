if (!requireNamespace("lintr", quietly = TRUE)) {
  stop("lintr is required. Run 'pixi install' to add dependencies.")
}

if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
}

lints <- lintr::lint_package()

if (length(lints) > 0) {
  print(lints)
  quit(status = 1)
}
