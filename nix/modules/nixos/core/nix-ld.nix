{
  # Prebuilt Linux binaries (mise-installed tools, uv's Pythons, npm packages
  # with native code, Playwright browsers) expect the standard dynamic linker,
  # which NixOS does not have. nix-ld provides it, with a default set of
  # common libraries (zlib, openssl, libstdc++, ...). Libraries beyond those
  # (browsers need X11/GTK ones) belong in a project's dev shell.
  programs.nix-ld.enable = true;
}
