# Python and Node trust the corporate root CAs (Zscaler's TLS inspection):
# those are in Ubuntu's certificate store, where IT deploys them.
{ config, lib, ... }:
let
  caBundle = "/etc/ssl/certs/ca-certificates.crt";
in
{
  config = lib.mkIf config.my.corporate.enable {
    programs.zsh.sessionVariables = {
      REQUESTS_CA_BUNDLE = caBundle;
      NODE_EXTRA_CA_CERTS = caBundle;
      # (Node 24 refuses --use-system-ca together with --use-openssl-ca)
      NODE_OPTIONS = "--use-openssl-ca";
    };
  };
}
