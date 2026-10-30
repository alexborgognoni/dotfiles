# The identity secrets (the SSH and GPG private keys), one row each. Everything
# that handles them reads this table:
#   NixOS               nixos/core/secrets.nix           group "personal"
#   standalone          home/standalone/secrets.nix      group "personal"
#   corporate laptop    home/corporate/identity.nix      group "work"
# and home/identity/ gets the files through my.identity.files.<slot>.
#
#   slot   the my.identity.files entry it fills
#   name   the key inside the sops file (and sops.secrets.<name>)
#   file   the encrypted file (.sops.yaml says who can decrypt it)
#   group  "personal": every machine; "work": only the corporate laptop
#
# A new secret is one row here (and a value in its sops file).
{ lib }:
rec {
  rows = [
    {
      slot = "sshPersonal";
      name = "ssh-personal";
      file = ../../secrets/personal.yaml;
      group = "personal";
    }
    {
      slot = "gpgPersonal";
      name = "gpg-personal";
      file = ../../secrets/personal.yaml;
      group = "personal";
    }
    {
      slot = "sshWork";
      name = "ssh-work";
      file = ../../secrets/work.yaml;
      group = "work";
    }
    {
      slot = "gpgWork";
      name = "gpg-work";
      file = ../../secrets/work.yaml;
      group = "work";
    }
  ];

  slots = map (row: row.slot) rows;

  # forGroup { config, group, extra } -> { secrets, files }:
  #   secrets  for sops.secrets (`extra`: owner, mode, ... for every one)
  #   files    for my.identity.files: where each decrypted secret ends up
  forGroup =
    {
      config,
      group,
      extra ? { },
    }:
    let
      inGroup = lib.filter (row: row.group == group) rows;
    in
    {
      secrets = lib.listToAttrs (
        map (row: lib.nameValuePair row.name ({ sopsFile = row.file; } // extra)) inGroup
      );
      files = lib.listToAttrs (
        map (row: lib.nameValuePair row.slot config.sops.secrets.${row.name}.path) inGroup
      );
    };
}
