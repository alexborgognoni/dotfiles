# Ubuntu work laptop: root-level configuration (system-manager). The user
# level is homes/work-laptop.nix; apt packages are apt/ (scripts/apt-layer.sh).
{
  my.user = "Alex";
  my.corporate.enable = true;
  system-manager.allowAnyDistro = false;

  # Hand-edited files of this laptop, taken over from the pre-Nix setup (the
  # originals are kept and restored on deactivation)

  # Docker behind the VPN and the corporate registry mirror
  environment.etc."docker/daemon.json" = {
    text = ''
      {
       "bip": "172.23.65.1/24",
       "mtu": 1280,
       "registry-mirrors": ["https://remote-docker.artifactory.dbgcloud.io"]
      }
    '';
    replaceExisting = true;
  };

  environment.etc."systemd/timesyncd.conf" = {
    text = ''
      [Time]
      NTP=ntp.ubuntu.com time.windows.com
      FallbackNTP=ntp.ubuntu.com
    '';
    replaceExisting = true;
  };

  # No release upgrade prompts (the corporate image stays on 22.04)
  environment.etc."update-manager/release-upgrades" = {
    text = ''
      [DEFAULT]
      Prompt=never
    '';
    replaceExisting = true;
  };
}
