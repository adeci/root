{
  config,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory) tailnet;
  inherit (self.inventory.lan.dns.underclass) host;
  bind = "127.0.0.1:8090";
  vars = config.clan.core.vars.generators.underclass.files;
in
{
  imports = [ self.inputs.underclass.nixosModules.default ];

  services.underclass = {
    enable = true;
    bindAddress = bind;
    # nixpkgs' cargo hook links aws-lc-sys and rusqlite against system libraries.
    package =
      self.inputs.underclass.packages.${pkgs.stdenv.hostPlatform.system}.underclass.overrideAttrs
        (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.aws-lc
            pkgs.sqlite
          ];
        });
    environmentFile = vars."underclass.env".path;
    settings.auto_codex_resets = false;
  };

  clan.core.vars.generators.underclass = {
    files.proxy-key.deploy = false;
    files.ui-token.deploy = false;
    files."underclass.env" = { };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      openssl rand -hex 32 | tr -d '\n' > "$out/proxy-key"
      openssl rand -hex 32 | tr -d '\n' > "$out/ui-token"
      printf 'UNDERCLASS_PROXY_KEY=%s\nUNDERCLASS_UI_TOKEN=%s\n' \
        "$(cat "$out/proxy-key")" "$(cat "$out/ui-token")" > "$out/underclass.env"
    '';
  };

  services.nginx.virtualHosts.${host} = {
    useACMEHost = "decio.us";
    forceSSL = true;
    extraConfig = ''
      allow 127.0.0.1;
      allow ${tailnet.cidr};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://${bind}";
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
        client_max_body_size 64m;
      '';
    };
  };
}
