test_that("generate_la_signature produces valid HMAC", {
  akid <- "test_akid"
  api_method <- "user_access_info"
  expires <- 1700000000000
  secret <- "test_secret"

  sig <- generate_la_signature(akid, api_method, expires, secret)

  expect_type(sig, "character")
  expect_gt(nchar(sig), 0)
})

test_that("generate_la_signature is deterministic", {
  akid <- "test_akid"
  api_method <- "user_access_info"
  expires <- 1700000000000
  secret <- "test_secret_456"

  sig1 <- generate_la_signature(akid, api_method, expires, secret)
  sig2 <- generate_la_signature(akid, api_method, expires, secret)

  expect_equal(sig1, sig2)
})

test_that("generate_la_signature matches the Python auth source when URL-encoded", {
  akid <- "0234wedkfjrtfd34er"
  api_method <- "entry_attachment"
  expires <- 264433207000
  secret <- "1234567890"
  python_expected <- paste0(
    "mT7pS%2BKgqlNseR0bo4YLQOVIsgOugMWzlQGllInXS25Q7V",
    "pA6lRmL0nUq%2FUUdrlF%2BWV7POYE1vcwvN%2Fpnac7bw%3D%3D"
  )

  sig <- generate_la_signature(akid, api_method, expires, secret)

  expect_equal(utils::URLencode(sig, reserved = TRUE), python_expected)
})

test_that("LabArchives signature is encoded once in query string", {
  akid <- "0234wedkfjrtfd34er"
  api_method <- "entry_attachment"
  expires <- 264433207000
  secret <- "1234567890"

  sig <- generate_la_signature(akid, api_method, expires, secret)
  encoded_sig <- utils::URLencode(sig, reserved = TRUE)

  req <- httr2::request("https://api.labarchives-gov.com/api/entries/entry_attachment") |>
    httr2::req_url_query(
      akid = akid,
      expires = expires,
      sig = sig
    )

  expect_true(grepl(paste0("sig=", encoded_sig), req$url, fixed = TRUE))
  expect_false(grepl("%252B|%252F|%253D", req$url))
})

test_that("la_expires defaults to current time in ms", {
  now_ms <- as.numeric(Sys.time()) * 1000
  expires <- ArchiveFlowR:::la_expires()

  expires_num <- as.numeric(expires)
  expect_false(is.na(expires_num))
  expect_true(abs(expires_num - now_ms) < 5000)
  expect_gt(expires_num, 1e12)
})

test_that("create_labarchives_client returns client object", {
  client <- create_labarchives_client(
    akid = "test_akid",
    password = "test_password",
    base_url = "https://api.labarchives-gov.com",
    cer_filepath = "/tmp/labarchives.pem"
  )

  expect_type(client, "list")
  expect_true("akid" %in% names(client))
  expect_true("base_url" %in% names(client))
  expect_true("password" %in% names(client))
  expect_true("cer_filepath" %in% names(client))
  expect_equal(client$cer_filepath, "/tmp/labarchives.pem")
})

test_that("create_labarchives_client uses default URL", {
  client <- create_labarchives_client(
    akid = "test_akid",
    password = "test_password"
  )

  expect_equal(client$base_url, "https://api.labarchives-gov.com/api")
  expect_null(client$cer_filepath)
})

test_that("parse_labarchives_access_info extracts user fields", {
  xml_string <- "<users>
    <id>12345</id>
    <fullname>Dr. Ada Lovelace</fullname>
    <email>ada@example.com</email>
  </users>"

  xml <- xml2::read_xml(xml_string)
  parsed <- parse_labarchives_access_info(xml)

  expect_true(parsed$success)
  expect_equal(parsed$user$id, "12345")
  expect_equal(parsed$user$fullname, "Dr. Ada Lovelace")
  expect_equal(parsed$user$email, "ada@example.com")
})

test_that("parse_labarchives_access_info falls back to uid", {
  xml_string <- "<users>
    <uid>abc123</uid>
    <email>fallback@example.com</email>
  </users>"

  xml <- xml2::read_xml(xml_string)
  parsed <- parse_labarchives_access_info(xml)

  expect_true(parsed$success)
  expect_equal(parsed$user$id, "abc123")
  expect_equal(parsed$user$email, "fallback@example.com")
})

test_that("parse_labarchives_access_info ignores nested notebook ids", {
  xml_string <- "<users>
    <id>user-123</id>
    <fullname>Test User</fullname>
    <email>user@example.com</email>
    <notebooks>
      <notebook>
        <id>nb-999</id>
        <name>Example Notebook</name>
      </notebook>
    </notebooks>
  </users>"

  xml <- xml2::read_xml(xml_string)
  parsed <- parse_labarchives_access_info(xml)

  expect_true(parsed$success)
  expect_equal(parsed$user$id, "user-123")
})

get_labarchives_test_config <- function() {
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
    base_url = env_or("LA_API_URL", "api_url", "https://api.labarchives-gov.com/api"),
    akid = env_or("LA_ACCESS_KEY_ID", "access_key_id", ""),
    password = env_or("LA_ACCESS_PASSWORD", "access_password", ""),
    user_id = Sys.getenv("LA_USER_ID")
  )
}

read_labarchives_auth_env <- function() {
  auth_code <- Sys.getenv("LA_AUTH_CODE")
  if (!nzchar(auth_code)) auth_code <- Sys.getenv("LABARCHIVES_AUTH_CODE")

  email <- Sys.getenv("LA_AUTH_EMAIL")
  if (!nzchar(email)) email <- Sys.getenv("LABARCHIVES_AUTH_EMAIL")

  if (!nzchar(auth_code) || !nzchar(email)) {
    return(NULL)
  }

  list(auth_code = auth_code, email = email)
}

get_labarchives_session <- local({
  cached <- NULL
  function() {
    if (!is.null(cached)) {
      return(cached)
    }

    config <- get_labarchives_test_config()
    client <- create_labarchives_client(config$akid, config$password, config$base_url)
    auth <- NULL
    uid <- config$user_id
    if (!nzchar(uid)) {
      auth <- read_labarchives_auth_env()
      if (is.null(auth)) {
        skip("LabArchives auth not available; set LA_USER_ID or LA_AUTH_CODE/LA_AUTH_EMAIL.")
      }

      login <- la_user_login(client, auth$auth_code, auth$email)
      if (!isTRUE(login$success)) {
        if (!is.null(login$error_type) && login$error_type == "network") {
          skip(paste("LabArchives endpoint not reachable:", login$error))
        }
        fail(paste("LabArchives login failed:", login$error))
      }
      uid <- login$uid
    }

    cached <<- list(client = client, uid = uid, config = config, auth = auth)
    cached
  }
})

test_that("labarchives login returns uid", {
  skip_if_no_labarchives_creds()

  session <- get_labarchives_session()
  if (is.null(session$auth)) {
    skip("LabArchives auth code/email not set; login flow not exercised.")
  }
  expect_true(nzchar(session$uid))
})

parse_query_params <- function(url) {
  query <- sub("^[^?]*\\?", "", url)
  if (identical(query, url) || !nzchar(query)) {
    return(list())
  }
  pairs <- strsplit(query, "&", fixed = TRUE)[[1]]
  params <- list()
  for (pair in pairs) {
    kv <- strsplit(pair, "=", fixed = TRUE)[[1]]
    key <- utils::URLdecode(kv[[1]])
    value <- if (length(kv) > 1) utils::URLdecode(paste(kv[-1], collapse = "=")) else ""
    params[[key]] <- value
  }
  params
}

test_that("la_login_url signs redirect_uri and uses base root", {
  client <- create_labarchives_client(
    akid = "test_akid",
    password = "test_password",
    base_url = "https://api.labarchives-gov.com/api"
  )
  redirect_uri <- "http://127.0.0.1:3838"
  expires <- "1700000000123"

  url <- la_login_url(client, redirect_uri = redirect_uri, expires = expires)
  params <- parse_query_params(url)

  expect_true(grepl("/api_user_login\\?", url))
  expect_true(startsWith(url, "https://api.labarchives-gov.com"))
  expect_equal(params$akid, "test_akid")
  expect_equal(params$expires, expires)
  expect_equal(params$redirect_uri, redirect_uri)

  expected_sig <- generate_la_signature("test_akid", redirect_uri, expires, "test_password")
  expect_equal(params$sig, expected_sig)
})

test_that("la_login_url includes no_cookies when requested", {
  client <- create_labarchives_client(
    akid = "test_akid",
    password = "test_password",
    base_url = "https://api.labarchives-gov.com/api"
  )
  url <- la_login_url(
    client,
    redirect_uri = "http://127.0.0.1:3838",
    expires = "1700000000123",
    no_cookies = TRUE
  )
  params <- parse_query_params(url)
  expect_equal(params$no_cookies, "1")
})

test_that("la_user_login passes auth_code and email to la_request", {
  client <- create_labarchives_client(
    akid = "test_akid",
    password = "test_password",
    base_url = "https://api.labarchives-gov.com/api"
  )
  captured <- list(endpoint = NULL, params = NULL)
  xml_string <- "<users>
    <id>user-123</id>
    <fullname>Test User</fullname>
    <email>user@example.com</email>
    <notebooks>
      <notebook><id>nb-1</id><name>Notebook One</name><is-default>true</is-default></notebook>
    </notebooks>
  </users>"

  result <- testthat::with_mocked_bindings(
    la_user_login(client, "auth-code-1", "user@example.com"),
    la_request = function(client, endpoint, params, method = "GET", api_method = NULL) {
      captured$endpoint <<- endpoint
      captured$params <<- params
      list(success = TRUE, data = xml2::read_xml(xml_string))
    },
    .package = "ArchiveFlowR"
  )

  expect_equal(captured$endpoint, "users/user_access_info")
  expect_equal(captured$params$login_or_email, "user@example.com")
  expect_equal(captured$params$password, "auth-code-1")
  expect_true(isTRUE(result$success))
  expect_equal(result$uid, "user-123")
  expect_equal(result$user$email, "user@example.com")
  expect_equal(result$notebooks[[1]]$id, "nb-1")
})

test_that("la_user_login propagates API failure", {
  client <- create_labarchives_client(
    akid = "test_akid",
    password = "test_password",
    base_url = "https://api.labarchives-gov.com/api"
  )

  result <- testthat::with_mocked_bindings(
    la_user_login(client, "bad-code", "user@example.com"),
    la_request = function(client, endpoint, params, method = "GET", api_method = NULL) {
      list(success = FALSE, error = "HTTP 401 Unauthorized", status = 401, error_type = "http")
    },
    .package = "ArchiveFlowR"
  )

  expect_false(isTRUE(result$success))
  expect_equal(result$error, "HTTP 401 Unauthorized")
  expect_equal(result$status, 401)
  expect_equal(result$error_type, "http")
})
