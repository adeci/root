{ config, ... }:
{

  imports = [
    ../../nix-modules/all.nix
    ../../nix-modules/dev.nix
    ../../nix-modules/shell.nix
    ../../nix-modules/home-manager.nix
  ];

  networking = {
    networkmanager.enable = true;
    hostName = "claudia";
  };

  time.timeZone = "America/New_York";

  services.nginx = {
    enable = true;
    streamConfig = ''
      # Minecraft usf dj2
      server {
        listen 25565;
        proxy_pass 100.99.42.67:25565;
      }
      server {
        listen 24454 udp;
        proxy_pass 100.99.42.67:24454;
      }

      # Minecraft rats
      server {
        listen 25566;
        proxy_pass 100.99.42.67:25566;
      }
      server {
        listen 24455 udp;
        proxy_pass 100.99.42.67:24455;
      }

      # Minecraft bros dj2
      server {
        listen 25568;
        proxy_pass 100.99.42.67:25568;
      }
      server {
        listen 24457 udp;
        proxy_pass 100.99.42.67:24457;
      }

      # dima rust
      server {
        listen 28082;
        proxy_pass 100.99.42.67:28082;
      }

    '';
  };

  networking.firewall.allowedTCPPorts = [
    25565
    25566
    25568
    28082
  ];
  networking.firewall.allowedUDPPorts = [
    24454
    24455
    24457
  ];

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.stateVersion = config.system.stateVersion;
  };

}
