# User applications and tools, from nixos-unstable (latest versions).
# Installed for the user at the NixOS level (not in Home Manager): they don't
# depend on the theme, so they are evaluated once instead of once per theme
# specialisation.
# Curated from what was installed on the Ubuntu machine (apt, snap, flatpak,
# cargo, pip, npm, brew, go, ~/.local/bin); Ubuntu/GNOME plumbing, build-only
# libraries and tools Nix replaces (nvm, pipx, mise, brew) are left out.
{ config, pkgs, ... }:
let
  u = pkgs.unstable;

  # Global Python for scripting and office automation; projects should use
  # their own environment (uv, poetry or a dev shell).
  python = u.python3.withPackages (
    ps: with ps; [
      boto3
      browser-cookie3
      cachetools
      diskcache
      docker
      email-validator
      fastapi
      keyring
      mkdocs-material
      openpyxl
      pandas
      pathvalidate
      pikepdf
      pypdf
      python-docx
      python-pptx
    ]
  );

  latex = u.texliveMedium.withPackages (
    ps: with ps; [
      latexmk
      collection-latexextra
      collection-fontsrecommended
      collection-fontsextra
    ]
  );
in
{
  users.users.${config.my.user.name}.packages = [
    python
    latex

    # Broken in unstable right now; from stable until fixed.
    pkgs.azure-cli # python fabric marked broken
    pkgs.semgrep # semgrep-core: patchelf assertion failure
  ]
  ++ (with u; [
    # Browsers and communication
    google-chrome
    chromium
    microsoft-edge
    teams-for-linux

    # Editors and notes
    vscode
    neovide
    obsidian

    # Media and graphics
    vlc
    obs-studio
    audacity
    handbrake
    inkscape
    ffmpeg
    imagemagick
    chafa
    exif
    exiftool
    resvg

    # Documents and reading
    foliate
    readest
    qpdf

    # Desktop utilities
    librepods
    pkgs.openwhispr

    # AI and coding agents
    claude-code
    codex
    github-copilot-cli
    opencode
    herdr
    pkgs.forgecode
    github-mcp-server
    mcp-language-server

    # Languages and toolchains
    nodejs
    pnpm
    bun
    typescript
    typescript-language-server
    rustup
    go
    uv
    poetry
    gcc
    gnumake
    cmake

    # Cloud and infrastructure
    awscli2
    azure-functions-core-tools
    azure-storage-azcopy
    cloudfoundry-cli
    terraform
    tflint
    kubectl
    kubecolor
    k9s
    ansible
    mkcert

    # Databases (clients; servers run per project in containers)
    postgresql
    squawk

    # Security and secrets
    bitwarden-cli
    fnox
    zizmor
    opensc

    # Shell utilities
    _7zz
    moreutils
    tree
    tokei
    lynx
    socat
    git-filter-repo
    process-compose
    llama-cpp
    onedrive

    # Windows applications
    wineWow64Packages.stable
  ]);
}
