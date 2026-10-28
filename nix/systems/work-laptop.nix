# Ubuntu work laptop: root-level configuration (system-manager). The user
# level is homes/work-laptop.nix; apt packages are ansible/ubuntu.yml.
{
  my.user = "Alex";
  system-manager.allowAnyDistro = false;
}
