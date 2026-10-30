# Git, SSH, GPG and GitHub CLI, with personal/work identities; the keys come
# from sops.
#
# Private keys come from sops secrets (secrets/personal.yaml, work.yaml),
# decrypted by NixOS (modules/nixos/core/secrets.nix) or, standalone, by
# Home Manager (standalone.nix); either way they arrive as my.identity.files.
#   personal profile: ~/.ssh/id_ed25519 = personal key
#   work profile:     ~/.ssh/id_ed25519 = work key,
#                     ~/.ssh/id_ed25519_personal = personal key
{
  config,
  lib,
  pkgs,
  ...
}:
let
  isWork = config.my.profile == "work";
  name = "Alex Borgognoni";
  personalEmail = "alex.bor0419@gmail.com";
  workEmail = "alex.borgognoni@deutsche-boerse.com";

  keys = {
    personal = {
      gpg = "A7B3752F07393182FB899C11D5A5A7F2739FC452";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAoxgUAc1803bi1jrE64lTyEZYHR4ADVvUONz0S0UJg alex.bor0419@gmail.com";
    };
    work = {
      gpg = "E69B33C4684313461110E75783E2B86EB1BD39F2";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICx+cqOXmeVOKmE6pOjeoiDOIY6DpS9QMulJDFgLJC7w alex.borgognoni@deutsche-boerse.com";
    };
  };
  primary = if isWork then keys.work else keys.personal;

  files = config.my.identity.files;
  link = config.lib.file.mkOutOfStoreSymlink;

  personalIdentity = {
    user = {
      email = personalEmail;
      signingkey = keys.personal.gpg;
    };
  };

  # Standalone on Ubuntu: use the system gpg, which shares its agent (and
  # pinentry) with the desktop session. On NixOS: Home Manager's.
  gpg = if config.my.standalone then "/usr/bin/gpg" else "${config.programs.gpg.package}/bin/gpg";
  gpgFiles = lib.filter (f: f.file != null) [
    {
      inherit (keys.personal) gpg;
      file = files.gpgPersonal;
    }
    {
      inherit (keys.work) gpg;
      file = if isWork then files.gpgWork else null;
    }
  ];
in
{
  options.my.identity.files = lib.genAttrs [ "sshPersonal" "sshWork" "gpgPersonal" "gpgWork" ] (
    name:
    lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path of the decrypted ${name} secret (set by the secrets backend).";
    }
  );

  config = {
    programs.git = {
      # Global gitignore (was ~/.config/git/ignore)
      ignores = [ "**/.claude/settings.local.json" ];
      enable = true;

      settings = {
        user = {
          inherit name;
          email = if isWork then workEmail else personalEmail;
        };

        init.defaultBranch = "main";
        user.signingkey = primary.gpg;
        commit.gpgsign = true;
        tag.gpgsign = true;
        pull.rebase = false;

        alias = {
          aa = "add -A .";
          aac = "!git add -A . && git commit";
          aacm = "!git add -A . && git commit -m";
          amend = "commit --amend -m";
          br = "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) [%(authorname)]' --sort=-committerdate";
          brD = "branch -D";
          brd = "branch -d";
          capf = "!git add -A && git commit --amend --no-edit && git push -f";
          cm = "commit -m";
          co = "checkout";
          cob = "checkout -b";
          coo = "!git fetch && git checkout";
          cp = "cherry-pick";
          f = "!git ls-files | grep -i";
          gr = "grep -Ii";
          la = "!git config -l | grep alias | cut -c 7-";
          last = "log -1 HEAD --stat";
          ll = ''log --pretty=format:"%C(yellow)%h%Cred%d\ %Creset%s%Cblue\ [%cn]" --decorate --numstat'';
          ls = ''log --pretty=format:"%C(yellow)%h%Cred%d\ %Creset%s%Cblue\ [%cn]" --decorate'';
          master = "!git checkout master && git pull origin";
          merged = "branch --merged";
          p = "!git push origin `git branch --show-current`";
          pf = "!git push --force origin `git branch --show-current`";
          plo = "pull origin";
          ploh = "pull origin HEAD";
          plom = "pull origin master";
          po = "push origin";
          poh = "push origin HEAD";
          pom = "push origin master";
          pub = ''!f() { git add . && git commit -m "$1" && git push; }; f'';
          search = "!git rev-list --all | xargs git grep -F";
          st = "status";
          sw = "switch";
          swc = "switch -c";
          tree = "log --";
          undo = "reset --soft HEAD^";
          unstage = "restore --staged";
          untracked = "clean -f -d";
          zap = "!git add . && git commit --amend --no-edit && git push -f";
        };
      }
      // lib.optionalAttrs isWork {
        url."git@github.deutsche-boerse.de:".insteadOf = "https://github.deutsche-boerse.de/";
      };

      includes = lib.optionals isWork [
        {
          condition = "gitdir:~/personal/";
          contents = personalIdentity;
        }
        {
          condition = "gitdir:~/dotfiles/";
          contents = personalIdentity;
        }
      ];
    };

    programs.gh = {
      enable = true;
      package = pkgs.unstable.gh;
      gitCredentialHelper.enable = true;
      settings = {
        git_protocol = "https";
        prompt = "enabled";
        aliases.co = "pr checkout";
      };
    };

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
          IdentityFile = if isWork then "~/.ssh/id_ed25519_personal" else "~/.ssh/id_ed25519";
        };
      }
      // lib.optionalAttrs isWork {
        "github.deutsche-boerse.de" = {
          HostName = "github.deutsche-boerse.de";
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
        };
      };
    };

    # The SSH agent is gnome-keyring's (gcr-ssh-agent), started with the session.

    # SSH keys from the decrypted secrets (owner-only files; ssh follows the link)
    home.file = lib.mkMerge [
      # (NixOS) classic keyring, see programs.gpg below
      (lib.mkIf (!config.my.standalone) { ".gnupg/common.conf".text = ""; })
      (lib.mkIf (files.sshPersonal != null || files.sshWork != null) {
        ".ssh/id_ed25519".source = link (if isWork then files.sshWork else files.sshPersonal);
        ".ssh/id_ed25519.pub".text = primary.ssh + "\n";
      })
      (lib.mkIf (isWork && files.sshPersonal != null) {
        ".ssh/id_ed25519_personal".source = link files.sshPersonal;
        ".ssh/id_ed25519_personal.pub".text = keys.personal.ssh + "\n";
      })
    ];

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
  };
}
