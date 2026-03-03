{
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
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
}
