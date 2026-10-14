#!/usr/bin/env bash
set -euo pipefail

shells=("$@")
if [ "${#shells[@]}" -eq 0 ]; then
  shells=(bash zsh)
fi
for shell in "${shells[@]}"; do
  case "$shell" in
    bash|zsh) ;;
    *) printf 'Unsupported test shell: %s\n' "$shell" >&2; exit 1 ;;
  esac
  command -v "$shell" >/dev/null || { printf 'Required test shell missing: %s\n' "$shell" >&2; exit 1; }
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/workspace/node_modules/.bin" "$test_dir/tools"
printf '{}\n' > "$test_dir/workspace/nx.json"
export FNX_TEST_DIR="$test_dir"
export PATH="$test_dir/tools:$PATH"
unset FNX_WORKSPACE_ROOT

cat > "$test_dir/workspace/node_modules/.bin/nx" <<'NX'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  show) cat "$FNX_TEST_DIR/project.json" ;;
  run) printf '%s\0' "$@" > "$FNX_TEST_DIR/actual" ;;
  *) exit 1 ;;
esac
NX
cat > "$test_dir/tools/fzf" <<'FZF'
#!/usr/bin/env bash
set -euo pipefail
printf 'picker\n' >> "$FNX_TEST_DIR/pickers"
cat >/dev/null
while [ "$#" -gt 0 ]; do
  if [ "$1" = --preview ]; then
    preview="$2"
    preview="${preview//\{\}/build}"
    "$SHELL" -c "$preview" > "$FNX_TEST_DIR/preview"
    shift
  fi
  shift
done
[ "$FNX_TEST_PICK" != cancel ] || exit 130
printf '%s\n' "$FNX_TEST_PICK"
FZF
chmod +x "$test_dir/workspace/node_modules/.bin/nx" "$test_dir/tools/fzf"
cd "$test_dir/workspace"

case_count=0
launch_fnx() {
  SHELL="$(command -v "$shell")" "$shell" -c 'exec "$@"' fnx "$repo_dir/bin/fnx" "$@"
}

# Restrict PATH to test missing dependencies regardless of installed system tools.
check_dependency_case() {
  local name="$1" dependency="$2" option="${3:-}"
  local actual_status=0 shell_path bash_path
  shell_path="$(command -v "$shell")"
  bash_path="$(command -v bash)"
  mkdir -p "$test_dir/dependencies"
  rm -f "$test_dir/dependencies/fzf" "$test_dir/dependencies/jq" "$test_dir/actual"
  ln -sf "$bash_path" "$test_dir/dependencies/bash"
  ln -sf "$(command -v cat)" "$test_dir/dependencies/cat"
  case "$dependency" in
    fzf) ln -s "$(command -v jq)" "$test_dir/dependencies/jq" ;;
    jq) ln -s "$test_dir/tools/fzf" "$test_dir/dependencies/fzf" ;;
  esac
  PATH="$test_dir/dependencies" "$shell_path" -c 'exec "$@"' fnx "$repo_dir/bin/fnx" "${option:-my-app}" > "$test_dir/stdout" 2> "$test_dir/stderr" || actual_status=$?
  if [ -n "$option" ]; then
    [ "$actual_status" -eq 0 ] && [ -s "$test_dir/stdout" ] && [ ! -s "$test_dir/stderr" ] || {
      printf 'FAIL %s: informational option requires dependencies\n' "$name"; exit 1;
    }
  else
    [ "$actual_status" -eq 1 ] && [ ! -s "$test_dir/stdout" ] || {
      printf 'FAIL %s: missing dependency exit/output\n' "$name"; exit 1;
    }
    local message
    message="$(cat "$test_dir/stderr")"
    [[ "$message" == "fnx: required dependency '${dependency:-fzf}' was not found on PATH. Install ${dependency:-fzf} with your system package manager and ensure it is on PATH." ]] || {
      printf 'FAIL %s: missing dependency message: %s\n' "$name" "$message"; exit 1;
    }
  fi
  [ ! -e "$test_dir/actual" ] || { printf 'FAIL %s: Nx ran without dependencies\n' "$name"; exit 1; }
  case_count=$((case_count + 1))
  printf 'PASS %s: %s\n' "$shell" "$name"
}

# Compare actual Nx argv as NUL-delimited strings, including spaces and separators.
check_case() {
  local name="$1" configurations="$2" pick="$3" picker_count="$4" status="$5" target="$6"
  shift 6
  local actual_status=0
  printf '{"targets":{"build":{"configurations":%s}}}\n' "$configurations" > "$test_dir/project.json"
  : > "$test_dir/pickers"
  rm -f "$test_dir/actual"
  FNX_TEST_PICK="$pick" launch_fnx my-app build "$@" || actual_status=$?
  [ "$actual_status" -eq "$status" ] || { printf 'FAIL %s: exit %s\n' "$name" "$actual_status"; exit 1; }
  [ "$(wc -l < "$test_dir/pickers")" -eq "$picker_count" ] || { printf 'FAIL %s: picker count\n' "$name"; exit 1; }
  if [ "$status" -eq 0 ]; then
    # Strip only the fnx separator from the expected arguments.
    if [ "${1:-}" = -- ]; then shift; fi
    printf '%s\0' run "$target" "$@" > "$test_dir/expected"
    cmp "$test_dir/expected" "$test_dir/actual" || { printf 'FAIL %s: argv\n' "$name"; exit 1; }
  else
    [ ! -e "$test_dir/actual" ] || { printf 'FAIL %s: Nx ran after cancellation\n' "$name"; exit 1; }
  fi
  case_count=$((case_count + 1))
  printf 'PASS %s: %s\n' "$shell" "$name"
}

for shell in "${shells[@]}"; do
  check_dependency_case 'missing fzf' fzf
  check_dependency_case 'missing jq' jq
  check_dependency_case 'both dependencies missing' ''
  check_dependency_case 'help without dependencies' '' --help
  check_dependency_case 'version without dependencies' '' --version
  multiple='{"development":{},"production":{}}'
  check_case 'no configurations' '{}' cancel 0 0 my-app:build --watch
  check_case 'one configuration' '{"production":{}}' cancel 0 0 my-app:build:production
  check_case 'multiple configurations' "$multiple" production 1 0 my-app:build:production
  check_case 'cancel required picker' "$multiple" cancel 1 130 unused
  check_case 'consume separator' '{}' cancel 0 0 my-app:build -- --watch 'value with spaces'
  check_case 'preserve later separator' '{}' cancel 0 0 my-app:build -- --watch -- --executor-option
  check_case 'long equals option' "$multiple" cancel 0 0 my-app:build --configuration=production
  check_case 'long separate option' "$multiple" cancel 0 0 my-app:build --configuration production
  check_case 'short separate option' "$multiple" cancel 0 0 my-app:build -c production
  check_case 'short equals option' "$multiple" cancel 0 0 my-app:build -c=production
  check_case 'separator and explicit configuration' "$multiple" cancel 0 0 my-app:build -- --configuration=production --watch
  check_case 'explicit overrides single configuration' '{"development":{}}' cancel 0 0 my-app:build --configuration production
  check_case 'executor configuration keeps picker' "$multiple" production 1 0 my-app:build:production -- -- --configuration=executor
  check_case 'similar option keeps picker' "$multiple" production 1 0 my-app:build:production --configuration-file=production

  # Exercise the target preview using the same shell fzf would use.
  printf '{"targets":{"build":{"configurations":{},"executor":"test:build"}}}\n' > "$test_dir/project.json"
  FNX_TEST_PICK=build launch_fnx my-app
  jq -e '. == {"configurations":{},"executor":"test:build"}' "$test_dir/preview" >/dev/null
  printf '%s\0' run my-app:build > "$test_dir/expected"
  cmp "$test_dir/expected" "$test_dir/actual"
  case_count=$((case_count + 1))
  printf 'PASS %s: target preview\n' "$shell"
done

printf '%s tests passed\n'  "$case_count"
