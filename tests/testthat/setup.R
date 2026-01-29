library(testthat)

if (!"ArchiveFlowR" %in% loadedNamespaces()) {
  stop("ArchiveFlowR package not loaded. Run tests with testthat::test_local().")
}

ArchiveFlowR::load_env_file()

labarchives_creds_missing <- function() {
  akid <- Sys.getenv("LA_ACCESS_KEY_ID")
  if (!nzchar(akid)) akid <- Sys.getenv("access_key_id")

  password <- Sys.getenv("LA_ACCESS_PASSWORD")
  if (!nzchar(password)) password <- Sys.getenv("access_password")

  placeholders <- c("your-access-key-id", "your-access-password")
  !nzchar(akid) || !nzchar(password) || akid %in% placeholders || password %in% placeholders
}

skip_if_no_labarchives_creds <- function(reason = "LabArchives credentials not available") {
  if (labarchives_creds_missing()) {
    skip(reason)
  }
}

skip_on_ci_no_labarchives <- function(reason = "No LabArchives credentials on CI") {
  if (Sys.getenv("CI") != "" && labarchives_creds_missing()) {
    skip(reason)
  }
}
