# Small system tweaks of the laptop, ported from its hand-edited /etc.
{ config, ... }:
{
  config = {
    # Present as an Apple device to AirPods (LibrePods); Bluetooth on at boot
    environment.etc."bluetooth/main.conf" = {
      text = ''
        [General]
        DeviceID = bluetooth:004C:0000:0000

        [Policy]
        AutoEnable=true
      '';
      replaceExisting = true;
    };
    # Prefer IPv4 over IPv6
    environment.etc."gai.conf" = {
      text = "precedence ::ffff:0:0/96  100\n";
      replaceExisting = true;
    };
    # File watchers (IDEs, dev servers)
    environment.etc."sysctl.d/40-inotify.conf" = {
      text = "fs.inotify.max_user_watches=524288\n";
      replaceExisting = true;
    };
    # Virtual input devices for user programs
    environment.etc."udev/rules.d/70-uinput.rules" = {
      text = ''KERNEL=="uinput", GROUP="input", MODE="0660", TAG+="uaccess"'' + "\n";
      replaceExisting = true;
    };

    # Apply sysctl and udev changes on switch, not only at the next boot
    systemd.services.dotfiles-apply-etc = {
      description = "Apply sysctl and udev settings from system-manager";
      wantedBy = [ "system-manager.target" ];
      restartTriggers = [
        config.environment.etc."sysctl.d/40-inotify.conf".source
        config.environment.etc."udev/rules.d/70-uinput.rules".source
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "/usr/lib/systemd/systemd-sysctl /etc/sysctl.d/40-inotify.conf"
          "/usr/bin/udevadm control --reload"
          "/usr/bin/udevadm trigger --subsystem-match=misc --sysname-match=uinput"
        ];
      };
    };
  };
}
