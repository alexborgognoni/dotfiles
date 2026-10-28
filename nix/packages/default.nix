# Package groups, from nixos-unstable (latest versions). Curated from what was
# installed on the Ubuntu machine (apt, snap, flatpak, cargo, pip, npm, brew,
# go, ~/.local/bin); Ubuntu/GNOME plumbing, build-only libraries and tools Nix
# replaces (nvm, pipx, mise, brew) are left out.
#
# A plain function of pkgs, so every consumer shares one evaluation:
#   NixOS             users.users.<name>.packages (modules/nixos/packages.nix)
#   Home Manager      my.packages.groups (modules/home/packages.nix), for
#                     standalone installs such as the Ubuntu work laptop
#
#   cli       terminal tools, languages, cloud, AI agents, Python, LaTeX
#   gui       graphical applications
#   browsers  Chrome and Edge: Nix on NixOS; apt on the work laptop, where the
#             vendor packages integrate with Intune/Entra sign-in
{ pkgs }:
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
  cli = [
    python
    latex

    # Broken in unstable right now; from stable until fixed.
    pkgs.azure-cli # python fabric marked broken
    pkgs.semgrep # semgrep-core: patchelf assertion failure

    # Not in nixpkgs: packaged in pkgs/
    pkgs.forgecode
  ]
  ++ (with u; [
    # AI and coding agents
    claude-code
    codex
    github-copilot-cli
    opencode
    herdr
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
    sops
    age
    ssh-to-age

    # Media and documents (command line)
    ffmpeg
    imagemagick
    chafa
    exif
    exiftool
    resvg
    qpdf

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
  ]);

  gui = [
    pkgs.openwhispr
  ]
  ++ (with u; [
    teams-for-linux
    vscode
    neovide
    obsidian
    vlc
    obs-studio
    audacity
    handbrake
    inkscape
    foliate
    readest
    librepods
    chromium
    wineWow64Packages.stable
  ]);

  browsers = with u; [
    google-chrome
    microsoft-edge
  ];
}
