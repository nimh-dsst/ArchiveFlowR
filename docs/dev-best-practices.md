# Development Best Practices

This guide captures the detailed workflow for ArchiveFlowR. Keep `AGENTS.md`
short; put durable package practices here.

## Scope

- ArchiveFlowR is a focused R package for LabArchives SSO authentication.
- The original Python ArchiveFlow auth implementation is the behavioral source
  of truth for auth signing, login URL construction, and user access lookup.
- The repo-root `.env` is the only shared credential/config input.
- Do not cache auth artifacts, write credential files, or commit secrets.

## Core workflow

- Use Git + a hosted repo (e.g., GitHub) to review changes and keep history.
- Keep package structure conventional: `R/` for code, `tests/testthat/` for
  tests, `man/` for docs, `inst/` for runtime assets.
- Prefer small, focused changes that keep tests and checks passing.
- Run all local tasks through Pixi from the repo root.

## Package organization

- All package R code lives in `R/` as function definitions.
- Avoid top-level executable code and `source()` in package files.
- Keep `R/` flat; use meaningful file names and group related helpers together.
- Use standard package locations:
  - `tests/` for tests.
  - `man/` for roxygen-generated documentation.
  - `inst/` for installed runtime assets, accessed with `system.file()`.
  - `data/` for exported package data.
  - `data-raw/` for data creation scripts, excluded via `.Rbuildignore`.
  - `vignettes/` only when a long-form workflow is needed.
- Use `devtools::load_all()` or `pkgload::load_all()` for interactive
  development instead of `source()`.

## Checks

- Run `pixi run r-cmd-check` regularly; it builds a clean tarball in a temp
  directory and runs `R CMD check` on that tarball. Do not check in-source.
- Keep ERROR/WARNING/NOTE output to zero; treat CRAN-style checks seriously.
- Treat CI results as the source of truth for portability issues.
- Keep file names portable: letters, numbers, dash, underscore.
- Avoid non-ASCII in code and object names unless the package needs it.
- If optional Suggests packages are unavailable in Pixi, `_R_CHECK_FORCE_SUGGESTS_`
  is set to `false` for CI, but run a full check with Suggests installed when
  possible.
- Exclude large references and non-package assets from the build using
  `.Rbuildignore` (for example, `.env`).
- Use `pixi run test` for fast local feedback and `pixi run r-cmd-check` before
  merging or tagging.

## Style and linting

- Follow the tidyverse style guide; format with `styler`.
- Lint with `lintr` using the project `.lintr` configuration.
- The initial `.lintr` is intentionally minimal; expand linters as existing issues
  are cleaned up.
- Local tasks:
  - `pixi run style` auto-formats package files.
  - `pixi run lint` lints the package.
  - `pixi run style-check` verifies formatting without modifying files.
- Install the repo-managed git hooks with `pixi run install-git-hooks` so
  formatting/linting runs before commits.

## Dependencies

- Put required packages in `Imports`, optional/testing tools in `Suggests`.
- Keep dependencies minimal; add new ones only when necessary.
- Use `pkg::fun()` for external calls and update `DESCRIPTION` accordingly.
- Avoid `library()`/`require()` in package code; use `pkg::` or roxygen imports
  to keep namespaces explicit.
- Dev-only tooling such as lintr, roxygen2, and styler belongs in `Suggests` or
  Pixi, not `Imports`.

## LabArchives auth compatibility

- Preserve the Python signature algorithm:
  `access_key_id + api_method + expires`, HMAC-SHA512 with the access password,
  then base64.
- In R, `generate_la_signature()` returns raw base64. Let `httr2` URL-encode it
  exactly once when constructing request URLs.
- For `api_user_login`, sign the redirect URI itself, not the endpoint name.
- Normalize API base URLs consistently so normal API calls use `/api/...` and
  login URLs use `/api_user_login`.
- Credentialed integration tests must skip cleanly when credentials or auth
  callback values are missing.
- Do not log credentials, auth codes, emails, or signed request URLs except
  through explicitly masked debug output.
- Keep demo apps under `inst/examples/` and make their extra dependencies
  optional via `Suggests`.

## Documentation

- Use roxygen2 to generate `man/` and keep `NAMESPACE` in sync.
- Keep `DESCRIPTION` accurate: Title, Description, Authors, License, etc.
- README should answer why to use it, how to use it, and how to install it.
- Track user-visible changes in `NEWS.md` once releases begin.
- Keep the license split clear: package code is MIT; docs and examples are
  CC BY 4.0.

## Testing

- Write focused, deterministic tests with testthat edition 3.
- Separate unit vs. integration tests; skip credentialed tests when env vars are
  missing.
- Prefer fixtures and helpers over repeated setup code.
- Test files must be named `test-*.R` and should mirror the organization of
  `R/` files.
- Do not edit `tests/testthat.R` unless changing package-level test bootstrapping.
- Keep tests self-sufficient. Use `tests/testthat/helper*.R` for shared helpers
  and `tests/testthat/setup*.R` for global setup/teardown.
- Store fixtures under `tests/testthat/fixtures/` and access them with
  `testthat::test_path()`.
- Write files only in the session temp directory with `withr::local_tempfile()`
  or `withr::local_tempdir()`.
- Use `testthat::skip_if_not_installed()`, `skip_on_cran()`, and related helpers
  for optional dependencies or external services.

## CI/CD

- GitHub Actions runs `pixi run r-cmd-check` across Linux, macOS, and Windows.
- Keep CI steps aligned with local tasks so failures are reproducible.
- Optional future CD: pkgdown site build/deploy or release artifacts.

## Release readiness

- For an internal GitHub package release, confirm `pixi run test`,
  `pixi run lint`, `pixi run style-check`, and `pixi run r-cmd-check` pass.
- Verify credentialed LabArchives auth in an environment with real `.env` values
  before announcing a release to users.
- Update version, README, and NEWS before tagging a release.
- Resolve all `R CMD check` issues before tagging a release.
