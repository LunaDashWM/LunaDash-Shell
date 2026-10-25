#!/usr/bin/env bash
set -euo pipefail

repo_url=https://github.com/LunaDashWM/LunaDash-Shell.git
slintlu_url=https://github.com/LunaDashWM/SlintLu.git
# Empty when the script is piped into bash: the source tree is downloaded below.
script_source=${BASH_SOURCE[0]:-}
script_dir=
[[ -z $script_source ]] || script_dir=$(cd -- "$(dirname -- "$script_source")" && pwd)
prefix=${HOME:?HOME must be set}/.local
custom_data_home=${XDG_DATA_HOME:-}
prefix_set=false
destdir=
dry_run=false
install_slintlu=false
check=auto

usage() {
    cat <<'EOF'
Usage: ./install.sh [--prefix DIR] [--destdir DIR] [--install-slintlu] [--no-check] [--dry-run]

Install this LunaDash Shell revision to PREFIX/share/lunadash/shell and a
`lunadash-shell` launcher to PREFIX/bin.
By default, files go to ~/.local/share/lunadash/shell (or
XDG_DATA_HOME/lunadash/shell when XDG_DATA_HOME is set) and ~/.local/bin.
For a system install, use: sudo ./install.sh --prefix /usr

The shell runs on SlintLu (https://github.com/LunaDashWM/SlintLu).
  --install-slintlu  build and install SlintLu with cargo when it is missing
  --no-check         do not compile the shell with `slintlu check` first

When run from a downloaded installer without the source tree, the script
fetches the current main branch first. It requires git and Bash.
EOF
}

while (($#)); do
    case "$1" in
        --prefix) (($# >= 2)) || { usage >&2; exit 2; }; prefix=$2; prefix_set=true; shift ;;
        --destdir) (($# >= 2)) || { usage >&2; exit 2; }; destdir=$2; shift ;;
        --install-slintlu) install_slintlu=true ;;
        --no-check) check=false ;;
        --dry-run) dry_run=true ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ -z $script_dir || ! -f $script_dir/shell.slint ]]; then
    command -v git >/dev/null 2>&1 || { echo 'git is required to download LunaDash-Shell.' >&2; exit 1; }
    checkout=$(mktemp -d "${TMPDIR:-/tmp}/lunadash-shell.XXXXXXXX")
    trap 'rm -rf -- "$checkout"' EXIT
    git -c maintenance.auto=false clone --quiet --depth 1 --branch main "$repo_url" "$checkout"
    args=()
    $prefix_set && args+=(--prefix "$prefix")
    [[ -z $destdir ]] || args+=(--destdir "$destdir")
    $install_slintlu && args+=(--install-slintlu)
    [[ $check == false ]] && args+=(--no-check)
    $dry_run && args+=(--dry-run)
    "$checkout/install.sh" "${args[@]}"
    exit $?
fi

if $prefix_set; then
    [[ $prefix == /* ]] || { echo 'PREFIX must be an absolute path.' >&2; exit 2; }
    data_directory=${prefix%/}/share
    bin_directory=${prefix%/}/bin
else
    data_directory=${custom_data_home:-$HOME/.local/share}
    [[ $data_directory == /* ]] || { echo 'XDG_DATA_HOME must be an absolute path.' >&2; exit 2; }
    bin_directory=$HOME/.local/bin
fi
shell_directory=${data_directory%/}/lunadash/shell
destination=${destdir%/}$shell_directory
launcher=${destdir%/}${bin_directory%/}/lunadash-shell
[[ $destination == /* ]] || { echo 'DESTDIR and PREFIX must form an absolute path.' >&2; exit 2; }

# SlintLu: use the one on PATH, or build it when asked to.
find_slintlu() {
    command -v slintlu 2>/dev/null || { [[ -x $HOME/.cargo/bin/slintlu ]] && echo "$HOME/.cargo/bin/slintlu"; } || true
}
slintlu=$(find_slintlu)
if [[ -z $slintlu ]] && $install_slintlu && ! $dry_run; then
    command -v cargo >/dev/null 2>&1 || { echo 'cargo is required to build SlintLu (https://rustup.rs).' >&2; exit 1; }
    echo 'Building SlintLu with cargo (this takes a few minutes)…'
    cargo install --locked --git "$slintlu_url" slintlu
    slintlu=$(find_slintlu)
fi

if $dry_run; then
    printf 'Would install LunaDash Shell from %s to %s\n' "$script_dir" "$destination"
    printf 'Would install the launcher to %s\n' "$launcher"
    printf 'SlintLu: %s\n' "${slintlu:-not found}"
    exit 0
fi

if [[ -n $slintlu && $check != false ]]; then
    "$slintlu" check "$script_dir" >/dev/null || { echo 'The shell does not compile with this SlintLu; not installing.' >&2; exit 1; }
fi

parent=$(dirname -- "$destination")
install -d -m 0755 -- "$parent"
stage=$(mktemp -d "$parent/.lunadash-shell-stage.XXXXXXXX")
cleanup() { rm -rf -- "$stage"; }
trap cleanup EXIT
while IFS= read -r -d '' file; do
    relative=${file#"$script_dir"/}
    case "$relative" in
        .git/*|.github/*|scripts/*|tests/*)
            continue
            ;;
        *.slint|*.po|theme.json|*.svg|*.png|*.jpg|*.jpeg|*.webp|LICENSE)
            install -D -m 0644 -- "$file" "$stage/$relative"
            ;;
    esac
done < <(find "$script_dir" -type f -print0)
[[ -f $stage/shell.slint ]] || { echo 'shell.slint is missing from the install set.' >&2; exit 1; }
chmod 0755 "$stage"

rm -rf -- "$destination"
mv -- "$stage" "$destination"
trap - EXIT

install -d -m 0755 -- "$(dirname -- "$launcher")"
cat > "$launcher" <<EOF
#!/bin/sh
# Starts the LunaDash shell with SlintLu. Extra arguments are options of \`slintlu run\`.
slintlu=\$(command -v slintlu || echo "\$HOME/.cargo/bin/slintlu")
exec "\$slintlu" --config "$shell_directory" "\$@"
EOF
chmod 0755 "$launcher"

printf 'Installed LunaDash Shell to %s\n' "$destination"
printf 'Installed the launcher %s\n' "$launcher"
if [[ -z $slintlu ]]; then
    printf '\nSlintLu was not found. Install it with ./install.sh --install-slintlu or:\n'
    printf '  cargo install --locked --git %s slintlu\n' "$slintlu_url"
fi
