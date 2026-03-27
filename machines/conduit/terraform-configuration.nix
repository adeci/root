{
  config,
  self,
  self',
  lib,
  ...
}:
{
  terraform.required_providers = {
    hcloud = {
      source = "hetznercloud/hcloud";
    };
    external = {
      source = "registry.opentofu.org/hashicorp/external";
      version = "~> 2.0";
    };
  };

  # Hetzner credentials from clan secrets
  data.external.hcloud-api-token = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "hcloud-api-token"
    ];
  };

  provider.hcloud = {
    token = config.data.external.hcloud-api-token "result.secret";
  };

  # SSH key
  resource.hcloud_ssh_key.alex = {
    name = "alex";
    public_key = builtins.head self.users.alex.sshKeys;
  };

  # Firewall
  resource.hcloud_firewall.conduit = {
    name = "conduit";

    rule = [
      # SSH
      {
        direction = "in";
        protocol = "tcp";
        port = "22";
        source_ips = [
          "0.0.0.0/0"
          "::/0"
        ];
      }
      # Minecraft server ports
      {
        direction = "in";
        protocol = "tcp";
        port = "25565-25569";
        source_ips = [
          "0.0.0.0/0"
          "::/0"
        ];
      }
      # Minecraft Voice Chat mod UDP ports
      {
        direction = "in";
        protocol = "udp";
        port = "24454-24458";
        source_ips = [
          "0.0.0.0/0"
          "::/0"
        ];
      }
    ];
  };

  # Server
  resource.hcloud_server.conduit = {
    name = "conduit";
    server_type = "cpx11";
    location = "ash";
    image = "ubuntu-24.04";
    ssh_keys = [ (config.resource.hcloud_ssh_key.alex "id") ];
    firewall_ids = [ (config.resource.hcloud_firewall.conduit "id") ];

    labels = {
      managed-by = "terraform";
    };
  };

  output = {
    conduit_ip = {
      value = config.resource.hcloud_server.conduit "ipv4_address";
      description = "Public IPv4 of conduit";
    };
    conduit_ssh = {
      value = "ssh root@\${hcloud_server.conduit.ipv4_address}";
      description = "SSH command for conduit";
    };
    conduit_id = {
      value = config.resource.hcloud_server.conduit "id";
      description = "Conduit server ID";
    };
  };
}
