# Repository Guidelines

## Project Structure & Module Organization

- `bin/fnx` is the Bash entry point. It discovers Nx workspaces, resolves the local CLI, selects projects/targets/configurations with `fzf`, and forwards arguments to Nx.
- `install.sh` copies the executable into `$PREFIX/bin` (default: `~/.local/bin`).
- `README.md` documents dependencies, installation, and usage; `LICENSE` contains the MIT license.
- `VERSION` stores the release version. Keep it synchronized with `FNX_VERSION` in `bin/fnx`.

`tests/arguments.sh` contains isolated CLI regression tests. There are no asset or generated-output directories.

## Build, Test, and Development Commands

No compilation or package installation step is required. Runtime dependencies are Bash, `fzf`, `jq`, and a workspace-local or global Nx CLI.

- `bash -n bin/fnx install.sh tests/arguments.sh`: check scripts for syntax errors.
- `bash tests/arguments.sh`: run argument and configuration regression tests using Bash and `jq`.
- `bash bin/fnx --help`: inspect usage output; currently requires `fzf` and `jq` on `PATH`.
- `bash bin/fnx --dry-run my-app test --watch`: inspect the resolved command from an Nx workspace; substitute a real project and target. Configuration selection may still prompt.
- `PREFIX=/tmp/fnx-install ./install.sh`: verify installation without changing your normal executable.

## Coding Style & Naming Conventions

Follow the existing Bash style: two-space indentation, `set -euo pipefail`, quoted variable expansions, and arrays for forwarded arguments. Use lowercase snake_case for local variables and underscore-prefixed helper functions such as `_find_workspace_root`. Reserve uppercase names for constants and exported configuration. Prefer `printf` for output and send errors to stderr. Preserve executable permissions on scripts.

## Testing Guidelines

Tests use a standalone Bash harness with temporary Nx and `fzf` stubs; no coverage threshold is configured. Add CLI regressions to `tests/arguments.sh`. Run syntax checks and manually exercise changed behavior in an Nx workspace. Check workspace discovery from subdirectories, local CLI preference, argument forwarding, cancellation, and zero/one/multiple configurations when relevant. Use dry runs to inspect commands before executing targets. If adding automated tests, keep fixtures isolated and document their invocation.

## Commit & Pull Request Guidelines

Pull requests should describe the behavior change, provide reproduction or usage examples, and list validation performed. Link relevant issues and update the README when options, dependencies, or installation behavior change.
