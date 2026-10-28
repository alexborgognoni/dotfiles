# Git, SSH and GitHub CLI, with personal/work identities
# (replaces chezmoi's dot_gitconfig.tmpl, dot_gitconfig-personal.tmpl and
# private_dot_ssh/config.tmpl).
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

  personalIdentity = {
    user = {
      email = personalEmail;
      signingkey = "D5A5A7F2739FC452";
    };
  };
in
{
  programs.git = {
    enable = true;

    settings = {
      user = {
        inherit name;
        email = if isWork then workEmail else personalEmail;
      };

      init.defaultBranch = "main";
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
}
