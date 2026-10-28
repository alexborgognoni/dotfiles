{
  # Removable media, trash and network locations for the file manager
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
}
