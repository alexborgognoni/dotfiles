# Shell functions

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Yazi file manager with directory changing support
y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd "$cwd"
    fi
    rm -f -- "$tmp"
}
