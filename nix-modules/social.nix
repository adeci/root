{
  pkgs,
  ...
}:
{

  environment.systemPackages = with pkgs; [
    # Wrap element-desktop to use gnome-keyring
    (element-desktop.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/element-desktop \
          --add-flags "--password-store=gnome-libsecret"
      '';
    }))
    # Wrap signal-desktop to use gnome-keyring as well (also an Electron app)
    (signal-desktop.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/signal-desktop \
          --add-flags "--password-store=gnome-libsecret"
      '';
    }))

    (vesktop.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ imagemagick ];
      postPatch = (oldAttrs.postPatch or "") + ''
        convert -coalesce ${
          pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
            hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
          }
        } static/splash.webp
      '';
    }))

  ];

}
