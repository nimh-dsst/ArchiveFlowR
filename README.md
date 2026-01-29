# ArchiveFlowR

<!-- badges: start -->
<!-- badges: end -->

ArchiveFlowR is an R package focused on LabArchives SSO authentication helpers.
It ports the working auth behavior from the original Python ArchiveFlow
implementation for R users.

## Installation

### Pixi (recommended for development)

```bash
pixi install
```

### R (install from source)

```bash
R CMD INSTALL .
```

## Quick Start (LabArchives SSO)

```r
library(ArchiveFlowR)

config <- get_config()
client <- create_labarchives_client(
  akid = config$labarchives_akid,
  password = config$labarchives_password,
  base_url = config$labarchives_url,
  cer_filepath = config$labarchives_ssl_cer
)

redirect_uri <- resolve_labarchives_redirect(config)
login_url <- la_login_url(client, redirect_uri = redirect_uri)

# Open login_url in a browser and complete the SSO flow.
# After redirect, exchange auth_code + email for a UID:
# result <- la_user_login(client, auth_code, email)
```

## Example App

Run the optional Shiny demo app to exercise the LabArchives SSO flow:

```r
shiny::runApp(system.file("examples/labarchives-auth-demo", package = "ArchiveFlowR"))
```

During development from the source tree:

```bash
pixi run Rscript -e 'shiny::runApp("inst/examples/labarchives-auth-demo")'
```

## Tasks

Run these from the `ArchiveFlowR` directory.

- `pixi run test`: run the full testthat suite.
- `pixi run lint`: lint the package with lintr.
- `pixi run style`: auto-format the package with styler.
- `pixi run style-check`: verify formatting without modifying files (CI).
- `pixi run r-cmd-check`: run `R CMD check` (mirrors CI).
- `pixi run install-git-hooks`: configure repo-managed git hooks (pre-commit).

## Configuration

Use the shared project configuration in the repo root. The `.env` file is the
single source of truth for credentials.

Required environment variables (supports root `.env`):
- `LA_ACCESS_KEY_ID` or `access_key_id`
- `LA_ACCESS_PASSWORD` or `access_password`

Optional:
- `LA_API_URL` or `api_url` (default `https://api.labarchives-gov.com/api`)
- `LA_SSL_CER` or `ssl_cer` (optional CA bundle for HTTPS)
- `app_host` (full URL used as the redirect URI)

## Logging

Logging uses levels: `debug`, `info`, `warn`, `error`, `none` (default `info`).
Set `ARCHIVEFLOW_LOG_LEVEL` in your environment or call
`options(archiveflow.log.level = "debug")` in an R session to change it.

## License

ArchiveFlowR package code is licensed under MIT. Documentation and example
materials under `docs/` and `inst/examples/` are licensed under Creative
Commons Attribution 4.0 International (CC BY 4.0).

## Documentation

- Development workflow: `docs/dev-best-practices.md`
