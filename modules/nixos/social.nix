{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.adeci.social;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.adeci.social.enable = lib.mkEnableOption "social apps (Element, Signal, Vesktop)";
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (element-desktop.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/element-desktop \
            --add-flags "--password-store=gnome-libsecret"
        '';
      }))
      (signal-desktop.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/signal-desktop \
            --add-flags "--password-store=gnome-libsecret"
        '';
      }))
      packages.vesktop
    ];
  };
}
