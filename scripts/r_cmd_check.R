#!/usr/bin/env Rscript
# File: scripts/r_cmd_check.R
# Purpose: Build a clean tarball and run R CMD check on it.

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run this script from the package root (DESCRIPTION not found).")
}

exclude_patterns <- c(
  "^\\.git($|/)",
  "^\\.pixi($|/)",
  "^\\.github($|/)",
  "^docs($|/)",
  "^\\.env$",
  "^\\.dockerignore$",
  "^AGENTS\\.md$",
  "^scripts($|/)",
  "^ArchiveFlowR_.*\\.tar\\.gz$",
  "^\\.Rcheck($|/)",
  "^\\.Rproj\\.user($|/)"
)

files <- list.files(
  root,
  all.files = TRUE,
  recursive = TRUE,
  include.dirs = TRUE,
  no.. = TRUE
)

keep <- rep(TRUE, length(files))
for (pat in exclude_patterns) {
  keep <- keep & !grepl(pat, files)
}
files <- files[keep]

staging_root <- tempfile("archiveflowr-check-")
dir.create(staging_root, recursive = TRUE)

pkg_dir <- file.path(staging_root, "ArchiveFlowR")
dir.create(pkg_dir)

paths <- file.path(root, files)
dirs <- files[dir.exists(paths)]
dirs <- dirs[nzchar(dirs)]
if (length(dirs)) {
  depth <- vapply(strsplit(dirs, "/"), length, integer(1))
  dirs <- dirs[order(depth)]
  for (d in dirs) {
    dir.create(file.path(pkg_dir, d), recursive = TRUE, showWarnings = FALSE)
  }
}

files_only <- setdiff(files, dirs)
if (length(files_only)) {
  from <- file.path(root, files_only)
  to <- file.path(pkg_dir, files_only)
  ok <- file.copy(
    from,
    to,
    overwrite = TRUE,
    recursive = FALSE,
    copy.mode = TRUE,
    copy.date = TRUE
  )
  if (!all(ok)) {
    stop("Failed to copy files: ", paste(files_only[!ok], collapse = ", "))
  }
}

r_bin <- Sys.which("R")
if (r_bin == "") {
  stop("R not found on PATH.")
}

old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(staging_root)

message("Building source tarball from clean copy...")
build_status <- system2(r_bin, c("CMD", "build", "--no-manual", "ArchiveFlowR"), stdout = "", stderr = "")
if (!identical(build_status, 0L)) {
  stop("R CMD build failed with status ", build_status)
}

archives <- list.files(staging_root, pattern = "^ArchiveFlowR_.*\\.tar\\.gz$", full.names = TRUE)
if (length(archives) == 0) {
  stop("No tarball produced by R CMD build.")
}

Sys.setenv(`_R_CHECK_FORCE_SUGGESTS_` = "false")
message("Running R CMD check on tarball...")
check_status <- system2(
  r_bin,
  c("CMD", "check", "--no-manual", "--as-cran", archives[[1]]),
  stdout = "",
  stderr = ""
)
if (!identical(check_status, 0L)) {
  quit(status = check_status)
}
