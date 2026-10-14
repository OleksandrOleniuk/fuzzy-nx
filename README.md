# fuzzy-nx

`fuzzy-nx` is a tiny terminal-native launcher for Nx targets, powered by `fzf`.
Its CLI command is `fnx`.

It is aimed at monorepos where remembering every project, target, and configuration is more annoying than running the command itself.

## What it does

- fuzzy-picks an Nx project when you do not provide one
- fuzzy-picks a target for that project
- skips the configuration prompt when there are none
- automatically uses the only configuration when exactly one exists
- fuzzy-picks a configuration when multiple exist and none is explicitly supplied
- forwards extra arguments to `nx run`
- prefers the workspace-local Nx CLI over a global install
- works from subdirectories by finding the nearest parent `nx.json`
- can print the final command without running it

## Shell support

Run `fnx` from either Bash or Zsh. Its executable uses Bash internally, so Bash
must be installed even when Zsh is your interactive shell. No shell plugin or
shell-specific wrapper is needed.

Run `./install.sh`, then invoke `fnx` normally. Do not source either script or
run them with `zsh`; their shebangs select Bash automatically.

If `~/.local/bin` is not on your `PATH`, add this to `~/.bashrc` for Bash or
`~/.zshrc` for Zsh, then open a new terminal:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Dependencies

- Bash
- [`fzf`](https://github.com/junegunn/fzf)
- [`jq`](https://jqlang.github.io/jq/)
- Nx, either installed in the workspace (`node_modules/.bin/nx`) or globally on `PATH`

If `fzf` or `jq` is missing from `PATH`, `fnx` exits with an error naming the
missing tool and suggesting installation with your system package manager.
`--help` and `--version` work without these dependencies.

A global Nx installation is **not required**. `fnx` prefers the workspace-local CLI so that the Nx version matches the repository.

## Install

### 1. Install dependencies

Install Bash, `curl`, `fzf`, and `jq` using your system package manager.
Choose the command for your system:

```sh
# Debian / Ubuntu
sudo apt update
sudo apt install bash curl fzf jq

# Arch Linux
sudo pacman -S bash curl fzf jq

# macOS (with Homebrew installed)
brew install bash curl fzf jq
```

Nx should be installed in the workspace where you will use `fnx` (see
[Dependencies](#dependencies)).

### 2. Download fnx with curl

Install the script into `~/.local/bin`:

```sh
mkdir -p "$HOME/.local/bin" &&
  curl -fsSL https://raw.githubusercontent.com/OleksandrOleniuk/fuzzy-nx/master/bin/fnx \
    -o "$HOME/.local/bin/fnx" &&
  chmod +x "$HOME/.local/bin/fnx"
```

`curl -fsSL` follows redirects, hides the progress meter, and reports download
errors, including HTTP failures. The script is made executable only after a
successful download.

Alternatively, install from a local checkout:

```sh
git clone https://github.com/OleksandrOleniuk/fuzzy-nx.git
cd fuzzy-nx
./install.sh
```

The installer defaults to `~/.local/bin/fnx`. To use a different directory:

```sh
PREFIX="$HOME/tools" ./install.sh
```

This installs to `$HOME/tools/bin/fnx`; add that directory to your `PATH`.

### 3. Add fnx to PATH

Add the following line to `~/.bashrc` for Bash or `~/.zshrc` for Zsh, then open
a new terminal. You can also run it in the current terminal to use `fnx` now:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### 4. Verify and run

```sh
fnx --version
fnx --help
```

From your Nx workspace, run `fnx` to choose a project and target, or inspect a
command before running it:

```sh
fnx --dry-run my-app build
fnx my-app build
```

Replace `my-app` and `build` with a project and target from your workspace.
Run the curl download command again to update a curl installation, or update
your checkout and rerun `./install.sh`.

## Usage

Fully interactive:

```sh
fnx
```

Pick only the target:

```sh
fnx my-app
```

Run a known project + target:

```sh
fnx my-app test
```

Forward arguments to Nx:

```sh
fnx my-app test --watch
fnx my-app build --configuration=production
fnx my-app build -- --configuration=production
fnx my-app build -c production
```

An explicit `--configuration` or `-c` option skips automatic configuration
selection and its picker. Both `--configuration=production` and
`--configuration production` are supported. A `--` immediately after the project
and target is consumed by fnx; later separators are preserved for Nx.

Print the resolved command without running it:

```sh
fnx --dry-run my-app test --watch
```

## Nx resolution

`fnx` searches upward from the current directory for `nx.json`. Once it finds the workspace root, it resolves Nx in this order:

1. `<workspace>/node_modules/.bin/nx`
2. `nx` on `PATH`

This avoids requiring a global Nx install and helps prevent version mismatches.

## Development checks

```sh
bash -n bin/fnx install.sh tests/arguments.sh
bash tests/arguments.sh
```

The regression tests require Bash, Zsh, and `jq`. They launch the executable
from both shells, including preview commands executed by the selected shell.
They use temporary workspaces and stub Nx and `fzf` executables; no Nx
installation or interactive input is needed.

To test only one shell, run `bash tests/arguments.sh bash` or
`bash tests/arguments.sh zsh`. The default checks both and fails if either shell
is unavailable.

## Why not Nx Console?

Nx Console is great if you want an IDE UI. `fnx` is intentionally narrower: it gives terminal-first users a quick way to discover and launch Nx targets without leaving the shell.

## License

MIT
