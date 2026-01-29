hooks_path <- ".githooks"

if (!dir.exists(hooks_path)) {
  stop("Missing .githooks directory. Ensure it exists before installing hooks.")
}

status <- system2("git", c("config", "core.hooksPath", hooks_path))
if (!identical(status, 0L)) {
  stop("Failed to configure git core.hooksPath.")
}

message("Configured git hooks path to ", hooks_path)
