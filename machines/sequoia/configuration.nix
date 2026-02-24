{ ... }:
{
  networking = {
    hostName = "sequoia";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  imports = [
    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    dev.enable = true;
    shell.enable = true;
    auto-timezone.enable = false;

    buildbot-master = {
      enable = true;
      admins = [ "adeci" ];
      github = {
        appId = 1234567; # TODO: replace with actual GitHub App ID after creation
        oauthId = "Ov23li0000000000000"; # TODO: replace with actual OAuth client ID
      };
    };
  };
}
