# Java trusts the corporate root CAs (Zscaler's TLS inspection), like Python and
# Node do (ca-env.nix). The JDK from Nix has its own baked store, without them
# (PKIX path building failed); Ubuntu's Java used the system store. The store is
# built from Ubuntu's certificate store, where IT deploys the roots (nothing
# corporate is in this repository), at every switch when the bundle changed.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  bundle = "/etc/ssl/certs/ca-certificates.crt";
  store = "${config.xdg.dataHome}/java/cacerts.p12";
  password = "changeit";
  trust = {
    "javax.net.ssl.trustStore" = store;
    "javax.net.ssl.trustStoreType" = "PKCS12";
    "javax.net.ssl.trustStorePassword" = password;
  };
  # -D... for every JVM (java prints a note about it on stderr), and for
  # Gradle's own settings, which a Gradle started from an IDE reads too
  options = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "-D${k}=${v}") trust);
in
{
  config = lib.mkIf config.my.corporate.enable {
    home.activation.javaTrustStore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -r ${bundle} ] && { [ ! -s ${store} ] || [ ${bundle} -nt ${store} ]; }; then
        run mkdir -p "$(dirname ${store})"
        # never fails the switch: Java just keeps the default store
        run sh -c '${config.programs.java.package}/bin/java ${./TrustStore.java} ${bundle} ${store}.new \
          && mv ${store}.new ${store}' || echo "warning: the Java trust store was not updated" >&2
      fi
    '';

    programs.zsh.sessionVariables.JAVA_TOOL_OPTIONS = options;

    programs.gradle.settings = lib.mapAttrs' (k: v: lib.nameValuePair "systemProp.${k}" v) trust;
  };
}
