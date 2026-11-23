# Every default application is also an explicit association. Lookups ("Open
# With" in the portal, `gio mime`, `xdg-open`) list the apps registered for a
# type from the mimeinfo.cache indexes and the associations in mimeapps.list;
# a default that only one of them knew gave "No apps available". The
# association is the one that does not depend on a generated cache.
{ config, lib, ... }:
{
  config = lib.mkIf config.xdg.mimeApps.enable {
    xdg.mimeApps.associations.added = config.xdg.mimeApps.defaultApplications;
  };
}
