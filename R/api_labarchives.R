# ===========================================================================
# HMAC-SHA512 Signature Generation
# ===========================================================================

#' Generate HMAC-SHA512 signature for LabArchives
#'
#' `r lifecycle::badge("stable")`
#' Creates the authentication signature required by LabArchives API.
#'
#' @param akid Application Key ID
#' @param api_method API method name (or redirect_uri for login)
#' @param expires Expiration timestamp
#' @param secret The secret key (user's password)
#' @return Base64-encoded HMAC-SHA512 signature (not URL-encoded)
#'
#' @export
generate_la_signature <- function(akid, api_method, expires, secret) {
  message <- paste0(akid, api_method, expires)
  signature_raw <- digest::hmac(
    key = secret,
    object = message,
    algo = "sha512",
    serialize = FALSE,
    raw = TRUE
  )
  openssl::base64_encode(signature_raw)
}

# ===========================================================================
# Auth Helpers
# ===========================================================================

#' Create an expires timestamp for LabArchives auth
#'
#' LabArchives expects an expiry timestamp in milliseconds in the API docs.
#'
#' @param offset_seconds Time from now in seconds (default 0)
#' @return Expiration timestamp as a string (milliseconds since epoch)
la_expires <- function(offset_seconds = 0) {
  expires <- (as.numeric(Sys.time()) + offset_seconds) * 1000
  sprintf("%.0f", expires)
}

#' Build auth parameters for LabArchives API requests
#'
#' @param client LabArchives client
#' @param api_method API method name used for signature
#' @param expires Optional precomputed expires timestamp
#' @return Named list with akid, expires, sig
la_auth_params <- function(client, api_method, expires = NULL) {
  if (is.null(expires)) {
    expires <- la_expires()
  }
  signature <- generate_la_signature(
    client$akid,
    api_method,
    expires,
    client$password
  )
  list(
    akid = client$akid,
    expires = expires,
    sig = signature
  )
}

# ===========================================================================
# Client Creation
# ===========================================================================

#' Create LabArchives API client
#'
#' `r lifecycle::badge("stable")`
#' Creates a client object for making authenticated requests to LabArchives.
#'
#' @param akid Application Key ID (Access Key ID)
#' @param password User password (used for HMAC signing)
#' @param base_url LabArchives API URL (default: production API)
#' @param cer_filepath Optional path to a CA bundle for SSL verification
#' @return A list containing client configuration
#'
#' @export
create_labarchives_client <- function(
  akid,
  password,
  base_url = "https://api.labarchives-gov.com/api",
  cer_filepath = NULL
) {
  base_url <- sub("/$", "", base_url)
  if (!grepl("/api$", base_url)) {
    base_url <- paste0(base_url, "/api")
  }

  list(
    akid = akid,
    password = password,
    base_url = base_url,
    cer_filepath = cer_filepath
  )
}

#' Make authenticated request to LabArchives
#'
#' `r lifecycle::badge("stable")`
#' Performs an HTTP request with HMAC-SHA512 authentication.
#'
#' @param client LabArchives client from create_labarchives_client()
#' @param endpoint API endpoint (e.g., "notebooks/user_tree")
#' @param params Additional parameters as named list
#' @param method HTTP method (default "GET")
#' @param api_method Optional API method name override (defaults to endpoint
#'   suffix)
#' @return List with success status and parsed XML data or error
#'
#' @export
la_request <- function(
  client,
  endpoint,
  params = list(),
  method = "GET",
  api_method = NULL
) {
  if (is.null(api_method) || !nzchar(api_method)) {
    api_method <- sub("^.*/", "", endpoint)
  }
  auth_params <- la_auth_params(client, api_method)

  url <- paste0(client$base_url, "/", endpoint)
  all_params <- c(auth_params, params)

  af_log_debug(
    "LabArchives request: ",
    method,
    " ",
    endpoint,
    " (api_method=",
    api_method,
    ")"
  )

  req <- NULL
  request_url <- NULL

  tryCatch(
    {
      req <- request(url) |>
        req_url_query(!!!all_params) |>
        req_method(method)
      request_url <- req$url

      has_cainfo <- !is.null(client$cer_filepath) &&
        nzchar(as.character(client$cer_filepath)) &&
        file.exists(client$cer_filepath)
      if (has_cainfo) {
        req <- req |> req_options(cainfo = client$cer_filepath)
      }

      resp <- req_perform(req)
      status <- resp_status(resp)
      af_log_debug("LabArchives response status: ", status)

      content <- resp_body_string(resp)

      xml <- tryCatch(read_xml(content), error = function(e) NULL)
      if (is.null(xml)) {
        af_log_debug("LabArchives response parse failed: ", endpoint)
        if (nzchar(content)) {
          af_log_debug("LabArchives response body: ", af_log_preview(content))
        }
        return(list(
          success = FALSE,
          error = "Failed to parse LabArchives response XML",
          status = status,
          raw_body = content,
          request_url = request_url,
          error_type = "parse"
        ))
      }

      error_node <- xml_find_first(xml, "//error")
      if (!is.na(xml_text(error_node))) {
        af_log_warn("LabArchives API error: ", endpoint)
        if (nzchar(xml_text(error_node))) {
          af_log_debug("LabArchives API error detail: ", xml_text(error_node))
        }
        if (nzchar(content)) {
          af_log_debug("LabArchives API error body: ", af_log_preview(content))
        }
        return(list(
          success = FALSE,
          error = xml_text(error_node),
          status = status,
          raw_body = content,
          request_url = request_url
        ))
      }

      if (!is.na(status) && status >= 400) {
        af_log_warn("LabArchives API error: ", endpoint, " status=", status)
        if (nzchar(content)) {
          af_log_debug("LabArchives API error body: ", af_log_preview(content))
        }
        return(list(
          success = FALSE,
          error = paste("HTTP", status),
          status = status,
          raw_body = content,
          data = xml,
          request_url = request_url
        ))
      }

      list(
        success = TRUE,
        data = xml,
        status = status,
        request_url = request_url
      )
    },
    error = function(e) {
      af_log_error(
        "LabArchives request failed: ",
        endpoint,
        " error=",
        conditionMessage(e)
      )
      resp <- NULL
      if (!is.null(e$resp)) {
        resp <- e$resp
      } else {
        resp <- attr(e, "resp", exact = TRUE)
      }

      status <- NA_integer_
      raw_body <- NULL

      if (!is.null(resp)) {
        status <- tryCatch(resp_status(resp), error = function(err) NA_integer_)
        raw_body <- tryCatch(resp_body_string(resp), error = function(err) NULL)
        if (is.null(request_url) || !nzchar(request_url)) {
          request_url <- tryCatch(resp$url, error = function(err) NULL)
        }
      }

      if ((is.null(request_url) || !nzchar(request_url)) && !is.null(req)) {
        request_url <- tryCatch(req$url, error = function(err) NULL)
      }

      if (!is.null(status) && !is.na(status)) {
        af_log_debug("LabArchives response status: ", status)
      }
      if (!is.null(raw_body) && nzchar(raw_body)) {
        af_log_debug("LabArchives response body: ", af_log_preview(raw_body))
      }

      error_type <- if (inherits(e, "curl_error")) "network" else "http"

      list(
        success = FALSE,
        error = conditionMessage(e),
        error_type = error_type,
        status = status,
        raw_body = raw_body,
        request_url = request_url
      )
    }
  )
}

# ===========================================================================
# SSO Login
# ===========================================================================

#' Build LabArchives login URL
#'
#' `r lifecycle::badge("stable")`
#' Generates a browser login URL for the LabArchives API auth flow.
#'
#' @param client LabArchives client (akid and password)
#' @param redirect_uri Redirect URI to receive the auth_code/email
#' @param expires Optional expiry timestamp (ms)
#' @param no_cookies Whether to append no_cookies=1 (default FALSE)
#' @return Login URL string
#'
#' @export
la_login_url <- function(
  client,
  redirect_uri = NULL,
  expires = NULL,
  no_cookies = FALSE
) {
  if (is.null(redirect_uri) || redirect_uri == "") {
    stop("redirect_uri is required for LabArchives login URL")
  }

  if (is.null(expires)) {
    expires <- la_expires()
  }

  signature <- generate_la_signature(
    client$akid,
    redirect_uri,
    expires,
    client$password
  )

  base_root <- sub("/api/?$", "", client$base_url)
  params <- list(
    akid = client$akid,
    expires = expires,
    redirect_uri = redirect_uri,
    sig = signature
  )
  if (isTRUE(no_cookies)) {
    params$no_cookies <- 1
  }

  req <- request(paste0(base_root, "/api_user_login")) |>
    req_url_query(!!!params)

  req$url
}

#' Parse LabArchives user access info response
#'
#' `r lifecycle::badge("stable")`
#' @param xml XML document from user_access_info
#' @return List with success flag, user data, or error
#'
#' @export
parse_labarchives_access_info <- function(xml) {
  if (is.null(xml)) {
    return(list(success = FALSE, error = "User access info response was empty"))
  }

  normalize_text <- function(value) {
    if (is.na(value) || !nzchar(value)) {
      return(NA_character_)
    }
    value
  }

  root <- xml_root(xml)
  if (is.null(root)) {
    return(list(success = FALSE, error = "User access info response was empty"))
  }
  af_log_debug("LabArchives user_access_info root tag: ", xml_name(root))

  user_id <- normalize_text(xml_text(xml_find_first(root, "./id")))
  if (is.na(user_id) || !nzchar(user_id)) {
    user_id <- normalize_text(xml_text(xml_find_first(root, "./uid")))
  }

  if (is.na(user_id) || !nzchar(user_id)) {
    child_tags <- xml_name(xml_children(root))
    if (length(child_tags) > 0) {
      af_log_debug(
        "LabArchives user_access_info missing user id; tags=",
        paste(child_tags, collapse = ",")
      )
    }
    return(list(success = FALSE, error = "Could not retrieve user ID"))
  }

  user <- list(
    id = user_id,
    fullname = normalize_text(xml_text(xml_find_first(root, "./fullname"))),
    email = normalize_text(xml_text(xml_find_first(root, "./email")))
  )

  notebooks_nodes <- xml_find_all(root, ".//notebook")
  notebooks <- lapply(notebooks_nodes, function(nb) {
    nb_id <- normalize_text(xml_text(xml_find_first(nb, "id")))
    nb_name <- normalize_text(xml_text(xml_find_first(nb, "name")))
    if (is.na(nb_id) || !nzchar(nb_id) || is.na(nb_name) || !nzchar(nb_name)) {
      return(NULL)
    }
    list(
      id = nb_id,
      name = nb_name,
      is_default = normalize_text(xml_text(xml_find_first(nb, "is-default")))
    )
  })
  notebooks <- Filter(Negate(is.null), notebooks)

  af_log_debug(
    "LabArchives user_access_info parsed uid=",
    user$id,
    " notebooks=",
    length(notebooks)
  )

  list(success = TRUE, user = user, notebooks = notebooks)
}

#' Exchange auth_code/email for user UID
#'
#' `r lifecycle::badge("stable")`
#' @param client LabArchives client (akid and password)
#' @param auth_code Auth code from login redirect
#' @param email Email from login redirect
#' @return List with success status and UID
#'
#' @export
la_user_login <- function(client, auth_code, email) {
  result <- la_request(
    client,
    "users/user_access_info",
    list(login_or_email = email, password = auth_code),
    api_method = "user_access_info"
  )

  if (!result$success) {
    return(result)
  }

  parsed <- parse_labarchives_access_info(result$data)
  if (!isTRUE(parsed$success)) {
    return(list(success = FALSE, error = parsed$error))
  }

  list(
    success = TRUE,
    uid = parsed$user$id,
    user = parsed$user,
    notebooks = parsed$notebooks,
    data = result$data
  )
}
