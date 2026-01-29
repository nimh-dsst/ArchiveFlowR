# AGENTS

## Scope
- Keep this package focused on the R implementation of LabArchives SSO authentication.
- Treat the original Python ArchiveFlow auth implementation as the behavioral source of truth.
- Use the repo-root `.env` as the only shared credential/config input. Do not cache auth artifacts or commit secrets.
- Follow `docs/dev-best-practices.md` for package organization, testing, style, and release workflow.

## Commands
Run tasks from the repo root via Pixi:

- `pixi run test`
- `pixi run lint`
- `pixi run style-check`
- `pixi run style`
- `pixi run r-cmd-check`

Use `pixi run r-cmd-check` for full validation; it builds and checks a clean tarball in a temp directory rather than checking in-source.

## Change Discipline
- Keep changes small and focused.
- Run `pixi run test` for each behavior change and `pixi run r-cmd-check` before shipping.
- Avoid new runtime dependencies unless the auth implementation needs them.
- Keep `README.md`, `DESCRIPTION`, and `docs/dev-best-practices.md` aligned with current behavior.

## Logging
- Use `af_log_*` helpers with levels (`debug`, `info`, `warn`, `error`, `none`).
- Control verbosity via `ARCHIVEFLOW_LOG_LEVEL` or `options(archiveflow.log.level = ...)`.
- Log request/response details only at `debug`, and do not expose credentials or auth codes.
