# Git (signed commits, aliases, the work identity's host rewrite and the
# personal identity in ~/personal and ~/dotfiles) and the GitHub CLI.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  id = config.my.identity;
  inherit (id) work;
  primary = if work != null then work else id.personal;

  personalIdentity = {
    user = {
      email = id.personal.email;
      signingkey = id.personal.gpgKey;
    };
  };
in
{
  programs.git = {
    # Global gitignore (was ~/.config/git/ignore)
    ignores = [ "**/.claude/settings.local.json" ];
    enable = true;

    settings = {
      user = {
        inherit (id) name;
        email = primary.email;
      };

      init.defaultBranch = "main";
      user.signingkey = primary.gpgKey;
      commit.gpgsign = true;
      tag.gpgsign = true;
      pull.rebase = false;

      alias = import ./git-aliases.nix;
    }
    // lib.optionalAttrs (work != null) {
      url."git@${work.githubHost}:".insteadOf = "https://${work.githubHost}/";
    };

    includes = lib.optionals (work != null) [
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
}
