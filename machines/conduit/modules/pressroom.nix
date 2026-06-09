{
  pkgs,
  self,
  ...
}:
let
  deployRoot = "/srv/www/pressroom";
  domain = "gwong.xyz";
  securityHeaders = ''
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header X-Frame-Options SAMEORIGIN always;
  '';
in
{
  environment.systemPackages = [ pkgs.rsync ];

  users.groups.deploy-pressroom = { };

  users.users.deploy-pressroom = {
    isSystemUser = true;
    group = "deploy-pressroom";
    home = deployRoot;
    createHome = false;
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = self.users.alex.sshKeys;
  };

  systemd.tmpfiles.rules = [
    "d ${deployRoot} 0755 deploy-pressroom deploy-pressroom - -"
    "d ${deployRoot}/releases 0755 deploy-pressroom deploy-pressroom - -"
    "d ${deployRoot}/empty 0755 deploy-pressroom deploy-pressroom - -"
    "L ${deployRoot}/current - - - - ${deployRoot}/empty"
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "alex@decio.us";
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      default = true;
      serverAliases = [ "www.${domain}" ];
      root = "${deployRoot}/current";
      enableACME = true;
      forceSSL = true;

      locations."/".tryFiles = "$uri $uri/ =404";
      locations."~ \\.html$".extraConfig = ''
        add_header Cache-Control "no-cache" always;
        ${securityHeaders}
      '';

      extraConfig = ''
        access_log /var/log/nginx/pressroom.access.log;
        error_log /var/log/nginx/pressroom.error.log;

        ${securityHeaders}
      '';
    };
  };
}
