# Example material licensed under CC BY 4.0; see inst/examples/LICENSE.md.

if (!requireNamespace("shiny", quietly = TRUE)) {
  stop(
    "The LabArchives auth demo requires the shiny package. ",
    "Install it or run this app from the Pixi environment.",
    call. = FALSE
  )
}

find_source_root <- function(start_dir = getwd()) {
  dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  repeat {
    desc <- file.path(dir, "DESCRIPTION")
    if (file.exists(desc)) {
      lines <- readLines(desc, n = 5, warn = FALSE)
      if (any(grepl("^Package:\\s+ArchiveFlowR\\s*$", lines))) {
        return(dir)
      }
    }

    parent <- dirname(dir)
    if (identical(parent, dir)) {
      return(NULL)
    }
    dir <- parent
  }
}

if (!requireNamespace("ArchiveFlowR", quietly = TRUE)) {
  source_root <- find_source_root()
  if (!is.null(source_root) && requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(source_root, quiet = TRUE)
  }
}

if (!requireNamespace("ArchiveFlowR", quietly = TRUE)) {
  stop(
    "Install ArchiveFlowR before running this demo app, or run it from ",
    "the package source root with pkgload installed.",
    call. = FALSE
  )
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x)) y else x
}

mask_config <- function(value) {
  if (nzchar(value %||% "")) "configured" else "missing"
}

config <- ArchiveFlowR::get_config()
default_redirect <- ArchiveFlowR::resolve_labarchives_redirect(config) %||% ""

ui <- shiny::fluidPage(
  shiny::titlePanel("LabArchives Auth Demo"),
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      shiny::textInput("redirect_uri", "Redirect URI", value = default_redirect),
      shiny::checkboxInput("no_cookies", "Add no_cookies=1", value = TRUE),
      shiny::actionButton("build_login", "Build Login URL"),
      shiny::tags$hr(),
      shiny::passwordInput("auth_code", "Auth code"),
      shiny::textInput("email", "Email"),
      shiny::actionButton("exchange", "Exchange Auth Code")
    ),
    shiny::mainPanel(
      shiny::h3("Configuration"),
      shiny::verbatimTextOutput("config_status"),
      shiny::h3("Login URL"),
      shiny::uiOutput("login_link"),
      shiny::h3("User Access"),
      shiny::verbatimTextOutput("login_result")
    )
  )
)

server <- function(input, output, session) {
  inferred_url <- shiny::reactive({
    protocol <- session$clientData$url_protocol %||% "http:"
    host <- session$clientData$url_hostname %||% "127.0.0.1"
    port <- session$clientData$url_port %||% ""
    path <- session$clientData$url_pathname %||% "/"

    host_port <- host
    if (nzchar(port) && !port %in% c("80", "443")) {
      host_port <- paste0(host, ":", port)
    }

    paste0(protocol, "//", host_port, path)
  })

  shiny::observeEvent(
    inferred_url(),
    {
      if (!nzchar(input$redirect_uri %||% "")) {
        shiny::updateTextInput(session, "redirect_uri", value = inferred_url())
      }
    },
    once = TRUE
  )

  client <- shiny::reactive({
    shiny::validate(
      shiny::need(nzchar(config$labarchives_akid), "LA_ACCESS_KEY_ID or access_key_id is not configured."),
      shiny::need(nzchar(config$labarchives_password), "LA_ACCESS_PASSWORD or access_password is not configured.")
    )

    ArchiveFlowR::create_labarchives_client(
      akid = config$labarchives_akid,
      password = config$labarchives_password,
      base_url = config$labarchives_url,
      cer_filepath = config$labarchives_ssl_cer
    )
  })

  login_url <- shiny::reactiveVal("")
  login_result <- shiny::reactiveVal(NULL)
  handled_callback <- shiny::reactiveVal("")

  build_login_url <- function() {
    shiny::validate(shiny::need(nzchar(input$redirect_uri), "Redirect URI is required."))

    ArchiveFlowR::la_login_url(
      client(),
      redirect_uri = input$redirect_uri,
      no_cookies = isTRUE(input$no_cookies)
    )
  }

  exchange_auth_code <- function(auth_code, email) {
    shiny::validate(
      shiny::need(nzchar(auth_code), "Auth code is required."),
      shiny::need(nzchar(email), "Email is required.")
    )

    login_result(ArchiveFlowR::la_user_login(client(), auth_code, email))
  }

  shiny::observeEvent(input$build_login, {
    login_url(build_login_url())
  })

  callback <- shiny::reactive({
    query <- shiny::parseQueryString(session$clientData$url_search %||% "")
    list(
      auth_code = query$auth_code %||% "",
      email = query$email %||% ""
    )
  })

  shiny::observeEvent(
    callback(),
    {
      auth_code <- callback()$auth_code
      email <- callback()$email

      if (!nzchar(auth_code)) {
        return()
      }

      shiny::updateTextInput(session, "auth_code", value = auth_code)
      if (nzchar(email)) {
        shiny::updateTextInput(session, "email", value = email)
      }

      callback_key <- paste(auth_code, email, sep = "\n")
      if (!identical(handled_callback(), callback_key) && nzchar(email)) {
        handled_callback(callback_key)
        exchange_auth_code(auth_code, email)
      }
    },
    ignoreInit = FALSE
  )

  shiny::observeEvent(input$exchange, {
    exchange_auth_code(input$auth_code, input$email)
  })

  output$config_status <- shiny::renderPrint({
    list(
      api_url = config$labarchives_url,
      access_key_id = mask_config(config$labarchives_akid),
      access_password = mask_config(config$labarchives_password),
      ssl_cer = if (nzchar(config$labarchives_ssl_cer)) config$labarchives_ssl_cer else "",
      redirect_uri = input$redirect_uri,
      inferred_local_url = inferred_url()
    )
  })

  output$login_link <- shiny::renderUI({
    url <- login_url()
    if (!nzchar(url)) {
      return(shiny::tags$p("Build a login URL to start the SSO flow."))
    }

    shiny::tags$a(
      "Open LabArchives login",
      href = url,
      target = "_blank",
      rel = "noopener noreferrer"
    )
  })

  output$login_result <- shiny::renderPrint({
    result <- login_result()
    if (is.null(result)) {
      cat("No user access result yet.\n")
      return(invisible(NULL))
    }

    if (isTRUE(result$success)) {
      print(list(
        success = TRUE,
        uid = result$uid,
        user = result$user,
        notebooks = result$notebooks
      ))
      return(invisible(NULL))
    }

    print(result[intersect(names(result), c("success", "error", "status", "error_type"))])
  })
}

shiny::shinyApp(ui, server)
