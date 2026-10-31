{
  # Shared by the nginx vhosts here via `useACMEHost = "decio.us"`.
  security.acme.certs."decio.us" = {
    extraDomainNames = [ "*.decio.us" ];
    group = "nginx";
    reloadServices = [ "nginx.service" ];
  };
}
