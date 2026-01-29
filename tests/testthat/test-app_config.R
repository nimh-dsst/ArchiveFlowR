test_that("get_config returns a list with expected keys", {
  config <- get_config()

  expect_type(config, "list")
  expect_true("app_host" %in% names(config))
  expect_true("labarchives_url" %in% names(config))
  expect_true("labarchives_ssl_cer" %in% names(config))
  expect_true("labarchives_akid" %in% names(config))
  expect_true("labarchives_password" %in% names(config))
})

test_that("get_config returns default values when env vars not set", {
  old_env_loaded <- getOption("archiveflow.env_loaded")
  old_host_lower <- Sys.getenv("app_host")

  options(archiveflow.env_loaded = TRUE)
  Sys.unsetenv("app_host")

  config <- get_config()

  expect_equal(config$app_host, "")

  if (nzchar(old_host_lower)) Sys.setenv(app_host = old_host_lower)
  options(archiveflow.env_loaded = old_env_loaded)
})

test_that("get_config uses labarchives ssl cert env when set", {
  old_env_loaded <- getOption("archiveflow.env_loaded")
  old_ssl <- Sys.getenv("LA_SSL_CER")
  old_ssl_lower <- Sys.getenv("ssl_cer")

  options(archiveflow.env_loaded = TRUE)
  Sys.setenv(LA_SSL_CER = "/tmp/labarchives.pem")
  Sys.unsetenv("ssl_cer")

  config <- get_config()
  expect_equal(config$labarchives_ssl_cer, "/tmp/labarchives.pem")

  if (nzchar(old_ssl)) Sys.setenv(LA_SSL_CER = old_ssl) else Sys.unsetenv("LA_SSL_CER")
  if (nzchar(old_ssl_lower)) Sys.setenv(ssl_cer = old_ssl_lower) else Sys.unsetenv("ssl_cer")
  options(archiveflow.env_loaded = old_env_loaded)
})

test_that("resolve_labarchives_creds falls back to config", {
  config <- list(
    labarchives_akid = "config_akid",
    labarchives_password = "config_password"
  )

  resolved <- resolve_labarchives_creds("", "", config)

  expect_equal(resolved$akid, "config_akid")
  expect_equal(resolved$password, "config_password")
})

test_that("resolve_labarchives_creds ignores input overrides", {
  config <- list(
    labarchives_akid = "config_akid",
    labarchives_password = "config_password"
  )

  resolved <- resolve_labarchives_creds("input_akid", "input_password", config)

  expect_equal(resolved$akid, "config_akid")
  expect_equal(resolved$password, "config_password")
})

test_that("resolve_labarchives_redirect uses app_host env", {
  old_app_host <- Sys.getenv("app_host")

  on.exit(
    {
      if (nzchar(old_app_host)) Sys.setenv(app_host = old_app_host) else Sys.unsetenv("app_host")
    },
    add = TRUE
  )

  Sys.setenv(app_host = "http://app.example.com")

  config <- list(app_host = "ignored")
  uri <- resolve_labarchives_redirect(config)

  expect_equal(uri, "http://app.example.com")
})

test_that("resolve_labarchives_redirect falls back to config", {
  old_app_host <- Sys.getenv("app_host")

  on.exit(
    {
      if (nzchar(old_app_host)) Sys.setenv(app_host = old_app_host) else Sys.unsetenv("app_host")
    },
    add = TRUE
  )

  Sys.unsetenv("app_host")

  config <- list(app_host = "http://config.example.com")
  uri <- resolve_labarchives_redirect(config)

  expect_equal(uri, "http://config.example.com")
})

test_that("resolve_labarchives_redirect returns NULL when unset", {
  old_app_host <- Sys.getenv("app_host")

  on.exit(
    {
      if (nzchar(old_app_host)) Sys.setenv(app_host = old_app_host) else Sys.unsetenv("app_host")
    },
    add = TRUE
  )

  Sys.unsetenv("app_host")

  config <- list(app_host = "")
  uri <- resolve_labarchives_redirect(config)

  expect_null(uri)
})

test_that("is_labarchives_configured returns FALSE when not configured", {
  config <- list(
    labarchives_akid = "",
    labarchives_password = ""
  )

  expect_false(is_labarchives_configured(config))
})

test_that("is_labarchives_configured returns TRUE when both AKID and password are set", {
  config <- list(
    labarchives_akid = "test_akid",
    labarchives_password = "test_password"
  )

  expect_true(is_labarchives_configured(config))
})

test_that("is_labarchives_configured returns FALSE when only AKID is set", {
  config <- list(
    labarchives_akid = "test_akid",
    labarchives_password = ""
  )

  expect_false(is_labarchives_configured(config))
})
