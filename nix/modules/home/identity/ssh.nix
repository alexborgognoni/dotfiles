# SSH: the config, and the keys from the decrypted secrets. The agent is
# gnome-keyring's (gcr-ssh-agent), started with the session.
{ config, lib, ... }:
let
  id = config.my.identity;
  inherit (id) work;
  files = id.files;
  link = config.lib.file.mkOutOfStoreSymlink;
  primary = if work != null then work else id.personal;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        IdentitiesOnly = "yes";
      };
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = if work != null then "~/.ssh/id_ed25519_personal" else "~/.ssh/id_ed25519";
      };
    }
    // lib.optionalAttrs (work != null) {
      ${work.githubHost} = {
        HostName = work.githubHost;
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  # Owner-only files; ssh follows the link
  home.file = lib.mkMerge [
    (lib.mkIf (files.sshPersonal != null || files.sshWork != null) {
      ".ssh/id_ed25519".source = link (if work != null then files.sshWork else files.sshPersonal);
      ".ssh/id_ed25519.pub".text = primary.sshPublicKey + "\n";
    })
    (lib.mkIf (work != null && files.sshPersonal != null) {
      ".ssh/id_ed25519_personal".source = link files.sshPersonal;
      ".ssh/id_ed25519_personal.pub".text = id.personal.sshPublicKey + "\n";
    })
  ];
}
