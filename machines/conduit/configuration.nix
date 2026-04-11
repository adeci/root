{ self, ... }:
{

  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/dev.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/cloudflared.nix
  ];

  time.timeZone = "America/New_York";

  services.nginx = {
    enable = true;
    streamConfig = ''
      # Minecraft rats rlc
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

      # Minecraft hunter server
      server {
        listen 25567;
        proxy_pass lazarus.tail0e36b8.ts.net:25565;
      }

    '';
  };

  networking.firewall.allowedTCPPorts = [
    25565
    25566
    25567
    25568
  ];
  networking.firewall.allowedUDPPorts = [
    24454
    24455
    24456
    24457
  ];

}
