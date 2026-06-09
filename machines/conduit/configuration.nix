{ self, pkgs, ... }:
{

  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/cloudflared.nix
  ];

  time.timeZone = "America/New_York";

  # Static Pressroom deploy target. Local publish or future CI can rsync
  # built files into releases/<git-sha> and atomically update current.
  environment.systemPackages = [ pkgs.rsync ];
  users.groups.deploy-pressroom = { };
  users.users.deploy-pressroom = {
    isSystemUser = true;
    group = "deploy-pressroom";
    home = "/srv/www/pressroom";
    createHome = false;
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = self.users.alex.sshKeys;
  };
  systemd.tmpfiles.rules = [
    "d /srv/www/pressroom 0755 deploy-pressroom deploy-pressroom - -"
    "d /srv/www/pressroom/releases 0755 deploy-pressroom deploy-pressroom - -"
    "d /srv/www/pressroom/empty 0755 deploy-pressroom deploy-pressroom - -"
    "L /srv/www/pressroom/current - - - - /srv/www/pressroom/empty"
  ];

  services.nginx = {
    enable = true;
    streamConfig = ''
      # Forgejo Git SSH
      server {
        listen 2222;
        proxy_pass sequoia.cymric-daggertooth.ts.net:2222;
      }

      # Minecraft rats rlc
      server {
        listen 25565;
        proxy_pass leviathan.cymric-daggertooth.ts.net:25565;
      }
      server {
        listen 24454 udp;
        proxy_pass leviathan.cymric-daggertooth.ts.net:24454;
      }

      # Minecraft rats
      server {
        listen 25566;
        proxy_pass leviathan.cymric-daggertooth.ts.net:25566;
      }
      server {
        listen 24455 udp;
        proxy_pass leviathan.cymric-daggertooth.ts.net:24455;
      }

      # Minecraft bros dj2
      server {
        listen 25568;
        proxy_pass leviathan.cymric-daggertooth.ts.net:25568;
      }
      server {
        listen 24457 udp;
        proxy_pass leviathan.cymric-daggertooth.ts.net:24457;
      }

      # Minecraft hunter server
      server {
        listen 25567;
        proxy_pass lazarus.tail0e36b8.ts.net:25565;
      }

      # Minecraft usf
      server {
        listen 25569;
        proxy_pass leviathan.cymric-daggertooth.ts.net:25569;
      }
      server {
        listen 24458 udp;
        proxy_pass leviathan.cymric-daggertooth.ts.net:24458;
      }

      # Minecraft jav
      server {
        listen 25570;
        proxy_pass leviathan.cymric-daggertooth.ts.net:25570;
      }
      server {
        listen 24459 udp;
        proxy_pass leviathan.cymric-daggertooth.ts.net:24459;
      }

    '';
  };

  networking.firewall.allowedTCPPorts = [
    2222
    25565
    25566
    25567
    25568
    25569
    25570
  ];
  networking.firewall.allowedUDPPorts = [
    24454
    24455
    24456
    24457
    24458
    24459
  ];

}
