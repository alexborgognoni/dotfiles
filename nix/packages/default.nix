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
  # Your LibrePods build (Rust rewrite + local changes), see ./librepods
  librepods = pkgs.callPackage ./librepods { };

  # Readest follows the live theme: its custom theme "Theme" gets the current
  # pack's colors (and the light/dark mode) before every start, and from the
  # `theme` command while Readest is closed (it rewrites its settings while
  # running). Select "Theme" once in Readest's settings.
  readestThemeSync = pkgs.writeShellApplication {
    name = "readest-theme-sync";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      pack="''${XDG_STATE_HOME:-$HOME/.local/state}/theme/current"
      settings="''${XDG_CONFIG_HOME:-$HOME/.config}/com.bilingify.readest/settings.json"
      [ -f "$pack/readest.json" ] && [ -f "$settings" ] || exit 0
      tmp="$(mktemp "$settings.XXXXXX")"
      jq --slurpfile t "$pack/readest.json" --arg mode "$(cat "$pack/polarity")" \
        '.globalReadSettings.customThemes = ([(.globalReadSettings.customThemes // [])[] | select(.name != "theme")] + $t)
         | .globalViewSettings.theme = $mode' "$settings" > "$tmp"
      mv "$tmp" "$settings"
    '';
  };
  readest = pkgs.symlinkJoin {
    name = "readest-themed";
    paths = [ u.readest ];
    postBuild = ''
      rm "$out/bin/readest"
      cat > "$out/bin/readest" <<EOF
      #!${pkgs.runtimeShell}
      ${readestThemeSync}/bin/readest-theme-sync || true
      exec ${u.readest}/bin/readest "\$@"
      EOF
      chmod +x "$out/bin/readest"
      ln -s ${readestThemeSync}/bin/readest-theme-sync "$out/bin/"
      # app grid entries start the wrapper too
      for f in "$out"/share/applications/*.desktop; do
        [ -e "$f" ] || continue
        cp --remove-destination "$(readlink -f "$f")" "$f"
        sed -i "s|^Exec=[^ ]*|Exec=$out/bin/readest|" "$f"
      done
    '';
  };
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
    google-cloud-sdk # gcloud, gsutil, bq
    k6
    # VM tools for the libvirt daemon (tests/ubuntu-vm, the NixOS VM)
    virt-manager # also virt-install
    cloud-utils # cloud-localds
    qemu-utils # qemu-img

    # PHP (formerly Laravel Herd Lite); Laravel itself comes per project
    # through composer (composer create-project laravel/laravel <app>)
    php
    php.packages.composer

    # Databases (clients; servers run per project: dev shells or containers)
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
