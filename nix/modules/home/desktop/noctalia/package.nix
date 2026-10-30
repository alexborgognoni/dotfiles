# The Noctalia package. The lock screen authenticates against the "login" PAM
# service. On other distributions that file belongs to the distribution and
# Nix's PAM cannot parse it (Debian's @include), so standalone Noctalia uses
# its own "noctalia" service, provided by the system layer
# (modules/system-manager/session.nix: /etc/pam.d/noctalia).
{
  config,
  pkgs,
}:
if config.my.standalone then
  pkgs.unstable.noctalia.overrideAttrs (old: {
    # Upstream's tests run on Hydra for the same sources; icon_resolver
    # depends on the build host's environment.
    doCheck = false;
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/shell/lockscreen/lock_screen.cpp \
        --replace-fail 'const std::string pamService = "login";' 'const std::string pamService = "noctalia";'
    '';
  })
else
  pkgs.unstable.noctalia
