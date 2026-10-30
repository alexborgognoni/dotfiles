# GPG: the agent, and the import of the secret keys (idempotent, ultimately
# trusted).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  id = config.my.identity;
  inherit (id) files work;

  # Standalone on Ubuntu: use the system gpg, which shares its agent (and
  # pinentry) with the desktop session. On NixOS: Home Manager's.
  gpg = if config.my.standalone then "/usr/bin/gpg" else "${config.programs.gpg.package}/bin/gpg";
  gpgFiles = lib.filter (f: f.file != null) (
    [
      {
        gpg = id.personal.gpgKey;
        file = files.gpgPersonal;
      }
    ]
    ++ lib.optional (work != null) {
      gpg = work.gpgKey;
      file = files.gpgWork;
    }
  );
in
{
  # (NixOS) classic keyring, see programs.gpg below
  home.file.".gnupg/common.conf" = lib.mkIf (!config.my.standalone) { text = ""; };

  programs.gpg.enable = !config.my.standalone;
  # Classic file keyring (pubring.kbx) instead of GnuPG 2.4's keyboxd: the
  # activation service and the desktop session would otherwise contend for
  # the keyboxd database lock. Same format as Ubuntu's GnuPG 2.2.
  services.gpg-agent = lib.mkIf (!config.my.standalone) {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # Import the GPG secret keys (idempotent) and trust them ultimately.
  home.activation.importGpgKeys = lib.mkIf (gpgFiles != [ ]) (
    # After sops-nix has (re)decrypted the secrets on this activation
    lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" "sops-nix" "sopsWithoutSystemd" ] (
      lib.optionalString (!config.my.standalone) ''
        run ${config.programs.gpg.package}/bin/gpgconf --kill keyboxd || true
      ''
      + lib.concatMapStrings (k: ''
        if [ -r ${lib.escapeShellArg k.file} ]; then
          if ! ${gpg} --batch --list-secret-keys ${k.gpg} >/dev/null 2>&1; then
            run ${gpg} --batch --import ${lib.escapeShellArg k.file}
          fi
          echo "${k.gpg}:6:" | run ${gpg} --batch --import-ownertrust
        else
          warnEcho "GPG key secret ${k.file} is not available (yet)"
        fi
      '') gpgFiles
    )
  );
}
