{ config, ... }:
{
  # SSH key — used only for Hetzner rescue console / initial provisioning.
  # Pinned to avoid server replacement when sshKeys order changes.
  resource.hcloud_ssh_key.alex = {
    name = "alex";
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVB44hBiASLPelTC//teEK3CpzrwswdBccLe9MKbaMp adecigear";
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
